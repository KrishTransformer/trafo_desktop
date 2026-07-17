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
              headers: const <String, Object?>{'X-Skip-Auth': true},
            ),
          );

      return StoredCadModel(
        bytes: response.data == null
            ? Uint8List(0)
            : Uint8List.fromList(response.data!),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
