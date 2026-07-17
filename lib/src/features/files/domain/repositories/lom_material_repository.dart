import '../../../../core/models/entity_list_query.dart';
import '../models/lom_material_list_response.dart';

abstract interface class LomMaterialRepository {
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query);
}
