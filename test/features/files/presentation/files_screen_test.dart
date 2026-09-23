import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/features/files/application/files_controller.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_line_item.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_list_response.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_request.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/files_design_repository.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/files_lom_repository.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/lom_material_repository.dart';
import 'package:trafo_desktop/src/features/files/presentation/files_screen.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';

void main() {
  testWidgets('files screen renders the desktop workflow sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FilesController(
      routeId: 'entity-31',
      lomRepository: _FakeFilesLomRepository(),
      lomMaterialRepository: _FakeLomMaterialRepository(),
      designRepository: _FakeFilesDesignRepository(),
    );

    await tester.pumpWidget(
      _buildScreen(
        controller: controller,
        summary: const DesignSummary(
          id: 'entity-31',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","vectorGroup":"Dyn11","isOLTC":false,"isCSP":false,"core":{"coreWeight":880},"hvFormulas":{"hvProcurementWeight":45},"lvFormulas":{"lvProcurementWeight":55},"tankAndOilFormulas":{"hvConnectionWeight":12,"lvConnectionWeight":14,"insulationWeight":18,"totalOil":320,"weightOfTankAndAcc":900,"totalRadiatorWeight":410,"channelWeight":22}}',
          fabrication:
              '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true,"fill_Vlv_Nos":1},"smpl_Vlv":{"smpl_Vlv":false,"smpl_Vlv_Nos":0},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customer Details'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('LOM'), findsWidgets);
    expect(find.text('CCC'), findsOneWidget);
    expect(find.text('Document Actions'), findsOneWidget);
    expect(find.text('Lamination'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save Design'), findsOneWidget);
  });

  testWidgets('files screen adds a custom row and saves the design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final designRepository = _FakeFilesDesignRepository();
    final controller = FilesController(
      routeId: 'entity-32',
      lomRepository: _FakeFilesLomRepository(),
      lomMaterialRepository: _FakeLomMaterialRepository(),
      designRepository: designRepository,
    );

    await tester.pumpWidget(
      _buildScreen(
        controller: controller,
        summary: const DesignSummary(
          id: 'entity-32',
          designId: '100k-22345',
          twoWindings:
              '{"designId":"100k-22345","vectorGroup":"Dyn11","isOLTC":false,"isCSP":false,"core":{"coreWeight":880},"hvFormulas":{"hvProcurementWeight":45},"lvFormulas":{"lvProcurementWeight":55},"tankAndOilFormulas":{"hvConnectionWeight":12,"lvConnectionWeight":14,"insulationWeight":18,"totalOil":320,"weightOfTankAndAcc":900,"totalRadiatorWeight":410,"channelWeight":22}}',
          fabrication:
              '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true,"fill_Vlv_Nos":1},"smpl_Vlv":{"smpl_Vlv":false,"smpl_Vlv_Nos":0},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Custom Row'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('files_add_description')),
      'Other Materials',
    );
    await tester.enterText(
      find.byKey(const Key('files_add_specification')),
      'Custom',
    );
    await tester.enterText(find.byKey(const Key('files_add_unit')), 'lot');
    await tester.enterText(find.byKey(const Key('files_add_quantity')), '2');
    await tester.enterText(find.byKey(const Key('files_add_rate')), '900');
    await tester.tap(find.byKey(const Key('files_add_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Other Materials'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Design'));
    await tester.pumpAndSettle();

    expect(designRepository.persistedEntityIds, <String>['entity-32']);
    expect(designRepository.persistedItems.single, hasLength(2));
    expect(
      designRepository.persistedItems.single.last.stringAt('description'),
      'Other Materials',
    );
  });
}

Widget _buildScreen({
  required FilesController controller,
  required DesignSummary summary,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FilesScreen(
        routeDesignId: summary.id,
        initialDesignSummary: summary,
        controller: controller,
      ),
    ),
  );
}

class _FakeFilesLomRepository implements FilesLomRepository {
  @override
  Future<List<LomLineItem>> generateLom(LomRequest request) async {
    return <LomLineItem>[
      LomLineItem.fromJson(<String, dynamic>{
        'description': 'Lamination',
        'specification': 'CRGO',
        'unit': 'kg',
        'quantity': 125.5,
        'rate': request.toJson()['lomRate']['lamination'] ?? 220,
        'cost': 27610,
      }),
    ];
  }
}

class _FakeLomMaterialRepository implements LomMaterialRepository {
  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) async {
    return LomMaterialListResponse(
      data: List<LomMaterialEntry>.generate(39, (index) {
        final label = index == 0 ? 'Lamination' : 'Material $index';
        return LomMaterialEntry.fromJson(<String, dynamic>{
          'id': 'material-$index',
          'materialName': label,
          'materialRate': index == 0 ? 220.0 : index.toDouble(),
        });
      }),
      total: 39,
    );
  }
}

class _FakeFilesDesignRepository implements FilesDesignRepository {
  final List<String> persistedEntityIds = <String>[];
  final List<List<LomLineItem>> persistedItems = <List<LomLineItem>>[];

  @override
  Future<DesignSummary> fetchDesign(String entityId) async {
    throw StateError('No fetched summary configured.');
  }

  @override
  Future<void> persistLom({
    required String entityId,
    required List<LomLineItem> items,
  }) async {
    persistedEntityIds.add(entityId);
    persistedItems.add(List<LomLineItem>.from(items));
  }
}
