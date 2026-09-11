import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/two_winding_design.dart';
import '../../domain/repositories/two_winding_calculation_repository.dart';

class HttpTwoWindingCalculationRepository
    implements TwoWindingCalculationRepository {
  HttpTwoWindingCalculationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<TwoWindingDesign> calculate(TwoWindingDesign request) {
    return _apiClient.post<TwoWindingDesign>(
      service: ApiService.core,
      path: '/calculate/2windings/circular',
      headers: const {'User-Calc': 'true'},
      data: request.toJson(),
      decoder: (data) => TwoWindingDesign.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }
}
