import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/entity_payload_sanitizer.dart';
import '../../domain/models/lom_material_draft.dart';
import '../../domain/repositories/lom_material_admin_repository.dart';

class HttpLomMaterialAdminRepository implements LomMaterialAdminRepository {
  HttpLomMaterialAdminRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> createMaterial(LomMaterialDraft draft) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/lomMaterial',
      data: sanitizeEntityPayload(draft.toJson()),
      decoder: (_) {},
    );
  }

  @override
  Future<void> deleteMaterial(String entityId) {
    return _apiClient.delete<void>(
      service: ApiService.common,
      path: '/entity/lomMaterial/$entityId',
      decoder: (_) {},
    );
  }

  @override
  Future<void> updateMaterial({
    required String entityId,
    required LomMaterialDraft draft,
  }) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/lomMaterial/$entityId',
      data: sanitizeEntityPayload(draft.toJson()),
      decoder: (_) {},
    );
  }
}
