import '../models/fabrication_calculation_request.dart';
import '../models/fabrication_calculation_result.dart';

abstract interface class FabricationCalculationRepository {
  Future<FabricationCalculationResult> calculate(
    FabricationCalculationRequest request,
  );
}
