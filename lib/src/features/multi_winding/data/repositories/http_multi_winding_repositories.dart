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
    final response = await _apiClient.put<Map<String, dynamic>>(
      service: ApiService.common,
      path: '/entity/design',
      data: sanitizeEntityPayload(<String, dynamic>{
        'designId': designId,
        'designType': 'multi',
        'multiWindings': design.toJson(),
      }),
      decoder: (data) => Map<String, dynamic>.from(data as Map<Object?, Object?>),
    );
    final nested = response['data'];
    return (response['id'] ?? (nested is Map ? nested['id'] : null) ?? '').toString();
  }
}
