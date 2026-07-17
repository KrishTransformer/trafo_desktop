import '../models/two_winding_design.dart';

abstract interface class TwoWindingDesignRepository {
  Future<String> createDesign({
    required String designId,
    required TwoWindingDesign design,
  });
}
