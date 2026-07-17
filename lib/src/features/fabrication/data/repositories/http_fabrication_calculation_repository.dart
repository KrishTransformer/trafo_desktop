import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/fabrication_calculation_request.dart';
import '../../domain/models/fabrication_calculation_result.dart';
import '../../domain/repositories/fabrication_calculation_repository.dart';

class HttpFabricationCalculationRepository
    implements FabricationCalculationRepository {
  HttpFabricationCalculationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<FabricationCalculationResult> calculate(
    FabricationCalculationRequest request,
  ) {
    return _apiClient.post<FabricationCalculationResult>(
      service: ApiService.common,
      path: '/calculate/fabrication',
      data: request.toJson(),
      decoder: (data) => FabricationCalculationResult.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }
}
