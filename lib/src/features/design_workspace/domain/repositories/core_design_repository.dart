import '../models/core_calculation_result.dart';

abstract interface class CoreDesignRepository {
  Future<void> persistCore({
    required String entityId,
    required CoreCalculationResult core,
  });
}
