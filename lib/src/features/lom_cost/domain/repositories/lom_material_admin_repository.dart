import '../models/lom_material_draft.dart';

abstract interface class LomMaterialAdminRepository {
  Future<void> createMaterial(LomMaterialDraft draft);

  Future<void> updateMaterial({
    required String entityId,
    required LomMaterialDraft draft,
  });

  Future<void> deleteMaterial(String entityId);
}
