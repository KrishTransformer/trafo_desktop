import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/core_calculation_request.dart';
import '../../domain/models/core_calculation_result.dart';
import '../../domain/repositories/core_calculation_repository.dart';

class HttpCoreCalculationRepository implements CoreCalculationRepository {
  HttpCoreCalculationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<CoreCalculationResult> calculate(CoreCalculationRequest request) {
    return _apiClient.post<CoreCalculationResult>(
      service: ApiService.common,
      path: '/calculate/core',
      data: request.toJson(),
      decoder: (data) => CoreCalculationResult.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }
}
