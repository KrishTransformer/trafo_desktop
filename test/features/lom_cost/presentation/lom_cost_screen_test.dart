import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_list_response.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/lom_material_repository.dart';
import 'package:trafo_desktop/src/features/lom_cost/application/lom_cost_controller.dart';
import 'package:trafo_desktop/src/features/lom_cost/domain/models/lom_material_draft.dart';
import 'package:trafo_desktop/src/features/lom_cost/domain/repositories/lom_material_admin_repository.dart';
import 'package:trafo_desktop/src/features/lom_cost/presentation/lom_cost_screen.dart';

void main() {
  testWidgets('lom cost screen renders rate management controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = LomCostController(
      materialRepository: _FakeLomMaterialRepository(),
      adminRepository: _FakeLomMaterialAdminRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LomCostScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOM Material Rate'), findsOneWidget);
    expect(
      find.text(
        'Manage material names and per-unit rates used in calculations.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Set Rates to Default'),
      findsOneWidget,
    );
    expect(find.text('Lamination'), findsOneWidget);
  });

  testWidgets('lom cost screen adds a material row', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adminRepository = _FakeLomMaterialAdminRepository();
    final controller = LomCostController(
      materialRepository: _FakeLomMaterialRepository(),
      adminRepository: adminRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LomCostScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('lom_cost_add_name')),
      'Other Material',
    );
    await tester.enterText(find.byKey(const Key('lom_cost_add_rate')), '88');
    await tester.tap(find.byKey(const Key('lom_cost_add_submit')));
    await tester.pumpAndSettle();

    expect(adminRepository.createdDrafts, hasLength(1));
    expect(adminRepository.createdDrafts.single.materialName, 'Other Material');
    expect(adminRepository.createdDrafts.single.materialRate, 88);
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
      ],
      total: 1,
    );
  }
}

class _FakeLomMaterialAdminRepository implements LomMaterialAdminRepository {
  final List<LomMaterialDraft> createdDrafts = <LomMaterialDraft>[];

  @override
  Future<void> createMaterial(LomMaterialDraft draft) async {
    createdDrafts.add(draft);
  }

  @override
  Future<void> deleteMaterial(String entityId) async {}

  @override
  Future<void> updateMaterial({
    required String entityId,
    required LomMaterialDraft draft,
  }) async {}
}
