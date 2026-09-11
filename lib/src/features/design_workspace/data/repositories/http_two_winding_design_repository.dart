import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/two_winding_design.dart';
import '../../domain/repositories/two_winding_design_repository.dart';

class HttpTwoWindingDesignRepository implements TwoWindingDesignRepository {
  HttpTwoWindingDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  static const Set<String> _blockedOwnershipKeys = <String>{
    'ownerId',
    'tenantUrl',
    'tenantURL',
    'tenentURL',
    'tenantDatabase',
  };

  @override
  Future<String> createDesign({
    required String designId,
    required TwoWindingDesign design,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      service: ApiService.common,
      path: '/entity/design',
      data: <String, dynamic>{
        'designId': designId,
        'designType': 'two',
        'twoWindings': _sanitizeJsonString(design.toJson()),
      },
      decoder: (data) =>
          Map<String, dynamic>.from(data as Map<Object?, Object?>),
    );

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

  String _sanitizeJsonString(Map<String, dynamic> json) {
    return jsonEncode(_sanitizeValue(json));
  }

  Object? _sanitizeValue(Object? value) {
    if (value is List<dynamic>) {
      return value.map<Object?>((entry) => _sanitizeValue(entry)).toList();
    }

    if (value is Map<Object?, Object?>) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_blockedOwnershipKeys.contains(key)) {
          continue;
        }
        sanitized[key] = _sanitizeValue(entry.value);
      }
      return sanitized;
    }

    if (value is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        if (_blockedOwnershipKeys.contains(entry.key)) {
          continue;
        }
        sanitized[entry.key] = _sanitizeValue(entry.value);
      }
      return sanitized;
    }

    return value;
  }
}
