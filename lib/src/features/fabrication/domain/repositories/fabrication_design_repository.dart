import '../models/fabrication_calculation_result.dart';

abstract interface class FabricationDesignRepository {
  Future<void> persistFabrication({
    required String entityId,
    required FabricationCalculationResult fabrication,
  });
}
