import '../../../../core/models/entity_list_query.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/lom_material_list_response.dart';
import '../../domain/repositories/lom_material_repository.dart';

class HttpLomMaterialRepository implements LomMaterialRepository {
  HttpLomMaterialRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) {
    return _apiClient.post<LomMaterialListResponse>(
      service: ApiService.common,
      path: '/entity/v2/lomMaterial',
      data: const <String, dynamic>{},
      queryParameters: query.toQueryParameters(),
      decoder: (data) => LomMaterialListResponse.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }
}
