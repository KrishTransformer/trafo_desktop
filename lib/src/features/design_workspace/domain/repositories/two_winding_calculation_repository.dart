import '../models/two_winding_design.dart';

abstract interface class TwoWindingCalculationRepository {
  Future<TwoWindingDesign> calculate(TwoWindingDesign request);
}
