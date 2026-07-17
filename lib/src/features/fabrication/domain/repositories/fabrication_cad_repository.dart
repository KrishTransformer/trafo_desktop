import '../models/cad_generation_request.dart';
import '../models/cad_generation_result.dart';
import '../models/stored_cad_model.dart';

abstract interface class FabricationCadRepository {
  Future<CadGenerationResult> generate3D(CadGenerationRequest request);

  Future<StoredCadModel> loadModel(String designId);
}
