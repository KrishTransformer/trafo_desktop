import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/entity_payload_sanitizer.dart';
import '../../domain/models/multi_winding_design.dart';
import '../../domain/repositories/multi_winding_repositories.dart';

class HttpMultiWindingCalculationRepository
    implements MultiWindingCalculationRepository {
  HttpMultiWindingCalculationRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> request) {
    return _apiClient.post<Map<String, dynamic>>(
      service: ApiService.multiWinding,
      path: '/api/multiWdgCalculator/',
      data: request,
      decoder: (data) => Map<String, dynamic>.from(data as Map<Object?, Object?>),
    );
  }
}

class HttpMultiWindingDesignRepository implements MultiWindingDesignRepository {
  HttpMultiWindingDesignRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<String> createDesign({
    required String designId,
    required MultiWindingDesign design,
  }) async {
    final response = await _apiClient.put<String>(
      service: ApiService.common,
      path: '/entity/design',
      data: sanitizeEntityPayload(<String, dynamic>{
        'designId': designId,
        'designType': 'multi',
        'multiWindings': design.toJson(),
      }),
      responseType: ResponseType.plain,
      decoder: _decodeCreateDesignResponse,
    );
    return response;
  }

  String _decodeCreateDesignResponse(dynamic data) {
    if (data is String) {
      final text = data.trim();
      if (text.isEmpty) {
        return '';
      }

      if (text.startsWith('{')) {
        return _readIdFromMap(
          Map<String, dynamic>.from(jsonDecode(text) as Map<Object?, Object?>),
        );
      }

      if (text.startsWith('"')) {
        final decoded = jsonDecode(text);
        return decoded is String ? decoded : text;
      }

      return text;
    }

    if (data is Map<Object?, Object?>) {
      return _readIdFromMap(Map<String, dynamic>.from(data));
    }

    return '';
  }

  String _readIdFromMap(Map<String, dynamic> response) {
    final directId = response['id'];
    if (directId is String && directId.isNotEmpty) {
      return directId;
    }

    final nestedData = response['data'];
    if (nestedData is Map<Object?, Object?>) {
      final nestedId = nestedData['id'];
      if (nestedId is String && nestedId.isNotEmpty) {
        return nestedId;
      }
    }

    return '';
  }
}
