import '../models/multi_winding_design.dart';

abstract interface class MultiWindingCalculationRepository {
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> request);
}

abstract interface class MultiWindingDesignRepository {
  Future<String> createDesign({
    required String designId,
    required MultiWindingDesign design,
  });
}
