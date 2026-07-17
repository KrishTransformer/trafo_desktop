import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_list_response.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/lom_material_repository.dart';
import 'package:trafo_desktop/src/features/lom_cost/application/lom_cost_controller.dart';
import 'package:trafo_desktop/src/features/lom_cost/domain/models/lom_material_draft.dart';
import 'package:trafo_desktop/src/features/lom_cost/domain/repositories/lom_material_admin_repository.dart';

void main() {
  test('initialize loads material rates', () async {
    final controller = LomCostController(
      materialRepository: _FakeLomMaterialRepository(),
      adminRepository: _FakeLomMaterialAdminRepository(),
    );

    await controller.initialize();

    expect(controller.state.materials, hasLength(2));
    expect(controller.state.materials.first.materialName, 'Lamination');
  });

  test('addMaterial validates inputs and creates a new entry', () async {
    final adminRepository = _FakeLomMaterialAdminRepository();
    final controller = LomCostController(
      materialRepository: _FakeLomMaterialRepository(),
      adminRepository: adminRepository,
    );

    await controller.initialize();
    final added = await controller.addMaterial(
      materialName: 'New Material',
      materialRate: '99',
    );

    expect(added, isTrue);
    expect(adminRepository.createdDrafts.single.toJson(), <String, dynamic>{
      'materialName': 'New Material',
      'materialRate': 99,
    });
  });

  test(
    'resetToDefaults deletes existing rows and recreates the defaults',
    () async {
      final adminRepository = _FakeLomMaterialAdminRepository();
      final controller = LomCostController(
        materialRepository: _FakeLomMaterialRepository(),
        adminRepository: adminRepository,
      );

      await controller.initialize();
      final reset = await controller.resetToDefaults();

      expect(reset, isTrue);
      expect(adminRepository.deletedIds, <String>['mat-1', 'mat-2']);
      expect(adminRepository.createdDrafts, isNotEmpty);
      expect(adminRepository.createdDrafts.first.materialName, 'Lamination');
    },
  );

  test('repository failures surface a user-facing message', () async {
    final controller = LomCostController(
      materialRepository: _ThrowingLomMaterialRepository(),
      adminRepository: _FakeLomMaterialAdminRepository(),
    );

    await controller.initialize();

    expect(controller.state.materials, isEmpty);
    expect(controller.state.errorMessage, 'Unable to load rates.');
  });
}

class _FakeLomMaterialRepository implements LomMaterialRepository {
  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) async {
    return LomMaterialListResponse(
      data: <LomMaterialEntry>[
        LomMaterialEntry.fromJson(<String, dynamic>{
          'id': 'mat-1',
          'materialName': 'Lamination',
          'materialRate': 220.0,
        }),
        LomMaterialEntry.fromJson(<String, dynamic>{
          'id': 'mat-2',
          'materialName': 'HV Conductor',
          'materialRate': 125.0,
        }),
      ],
      total: 2,
    );
  }
}

class _ThrowingLomMaterialRepository implements LomMaterialRepository {
  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) {
    throw const ApiException(
      type: ApiExceptionType.server,
      message: 'Unable to load rates.',
      statusCode: 500,
    );
  }
}

class _FakeLomMaterialAdminRepository implements LomMaterialAdminRepository {
  final List<LomMaterialDraft> createdDrafts = <LomMaterialDraft>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<void> createMaterial(LomMaterialDraft draft) async {
    createdDrafts.add(draft);
  }

  @override
  Future<void> deleteMaterial(String entityId) async {
    deletedIds.add(entityId);
  }

  @override
  Future<void> updateMaterial({
    required String entityId,
    required LomMaterialDraft draft,
  }) async {}
}
