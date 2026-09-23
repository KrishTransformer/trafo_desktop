import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/cad_generation_request.dart';
import '../../domain/models/cad_generation_result.dart';
import '../../domain/models/stored_cad_model.dart';
import '../../domain/repositories/fabrication_cad_repository.dart';

class HttpFabricationCadRepository implements FabricationCadRepository {
  HttpFabricationCadRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CadGenerationResult> generate3D(CadGenerationRequest request) {
    return _apiClient.post<CadGenerationResult>(
      service: ApiService.cad,
      path: '/cad/run-3d-generation',
      data: request.payload,
      queryParameters: request.toQueryParameters(),
      decoder: (data) => CadGenerationResult.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }

  @override
  Future<StoredCadModel> loadModel(String designId) async {
    try {
      final response = await _apiClient
          .clientFor(ApiService.storage)
          .get<List<int>>(
            '/models/$designId.glb',
            options: Options(
              responseType: ResponseType.bytes,
              headers: const <String, Object?>{
                'Accept': 'model/gltf-binary, application/octet-stream',
                'X-Skip-Auth': 'true',
              },
            ),
          );

      final bytes = response.data == null
          ? Uint8List(0)
          : Uint8List.fromList(response.data!);
      if (!_isGlb(bytes)) {
        throw ApiException(
          type: ApiExceptionType.badResponse,
          message: 'The downloaded 3D model is not a valid GLB file.',
          statusCode: response.statusCode,
          uri: response.realUri,
          responseData: bytes.isEmpty ? null : bytes.take(32).toList(),
        );
      }

      return StoredCadModel(bytes: bytes);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static bool _isGlb(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x67 &&
        bytes[1] == 0x6C &&
        bytes[2] == 0x54 &&
        bytes[3] == 0x46;
  }
}
