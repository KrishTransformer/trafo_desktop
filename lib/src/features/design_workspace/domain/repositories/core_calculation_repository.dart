import '../models/core_calculation_request.dart';
import '../models/core_calculation_result.dart';

abstract interface class CoreCalculationRepository {
  Future<CoreCalculationResult> calculate(CoreCalculationRequest request);
}
