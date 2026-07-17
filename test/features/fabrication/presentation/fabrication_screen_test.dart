import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/fabrication/application/fabrication_controller.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/cad_generation_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/cad_generation_result.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/drawings_status_create_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/drawings_status_entry.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_result.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/stored_cad_model.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/repositories/drawings_status_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/repositories/fabrication_cad_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/repositories/fabrication_calculation_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/repositories/fabrication_design_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/presentation/fabrication_screen.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';

void main() {
  testWidgets('fabrication screen renders the desktop workflow sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FabricationController(
      routeId: 'entity-11',
      calculationRepository: _FakeFabricationCalculationRepository(),
      designRepository: _FakeFabricationDesignRepository(),
      cadRepository: _FakeFabricationCadRepository(),
      drawingsStatusRepository: _FakeDrawingsStatusRepository(
        currentEntries: <DrawingsStatusEntry>[
          DrawingsStatusEntry.fromJson(<String, dynamic>{
            'id': 'status-1',
            'designId': '100k-12345',
            'message': 'Docker engine: preparing registries config',
            'status': 'Processing',
            'createdAt': DateTime.now()
                .subtract(const Duration(minutes: 5))
                .toUtc()
                .toIso8601String(),
          }),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildScreen(
        controller: controller,
        summary: const DesignSummary(
          id: 'entity-11',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","kVA":100,"highVoltage":11000,"lowVoltage":433,"vectorGroup":"Dyn11","core":{"coreDia":210,"limbHt":640,"cenDist":420},"tank":{"tankLength":1000,"tankWidth":700,"tankHeight":900,"tankWallThickness":6,"tankBottomThickness":8,"frameThickness":10,"tankLidThickness":5},"tankAndOilFormulas":{"transformerWeight":3450,"radiatorHeight":1200,"radiatorWidth":520,"noOfFinsPerRadiator":18,"noOfRadiators":4,"hvBushingCurrent":12,"lvBushingCurrent":145,"conservatorCapacity":200,"conservatorDia":320,"conservatorLength":1600},"coilDimensions":{"lvid":240,"lvod":300,"hvid":340,"hvod":420},"innerWindings":{"windingLength":550,"turnsPerPhase":18},"outerWindings":{"windingLength":680}}',
          core: '{"numberOfSteps":5}',
          fabrication:
              '{"tank":{"tank_L":900},"hvb":{"hvb_Pos":"tank","hvb_Volt":11000,"hvb_Amp":15},"lvb":{"lvb_Pos":"lid","lvb_Volt":433,"lvb_Amp":140},"restOfVariables":{"designId":"100k-12345","kVA":100}}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fabrication'), findsOneWidget);
    expect(find.text('Reference: 100k-12345'), findsOneWidget);
    expect(find.text('Tank Details'), findsOneWidget);
    expect(find.text('Radiator Details'), findsOneWidget);
    expect(find.text('Lid and Conservator Details'), findsOneWidget);
    expect(find.text('Accessories / Fittings'), findsOneWidget);
    expect(find.text('3D Preview'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Show Status'), findsOneWidget);
  });

  testWidgets('show status opens the fabrication status drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FabricationController(
      routeId: 'entity-11',
      calculationRepository: _FakeFabricationCalculationRepository(),
      designRepository: _FakeFabricationDesignRepository(),
      cadRepository: _FakeFabricationCadRepository(),
      drawingsStatusRepository: _FakeDrawingsStatusRepository(
        currentEntries: <DrawingsStatusEntry>[
          DrawingsStatusEntry.fromJson(<String, dynamic>{
            'id': 'status-1',
            'designId': '100k-12345',
            'message': 'Docker engine: preparing registries config',
            'status': 'Processing',
            'createdAt': DateTime.now()
                .subtract(const Duration(minutes: 5))
                .toUtc()
                .toIso8601String(),
          }),
          DrawingsStatusEntry.fromJson(<String, dynamic>{
            'id': 'status-2',
            'designId': '100k-12345',
            'message': 'Executing remote combo builder...',
            'status': 'Processing',
            'createdAt': DateTime.now()
                .subtract(const Duration(minutes: 4))
                .toUtc()
                .toIso8601String(),
          }),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildScreen(
        controller: controller,
        summary: const DesignSummary(
          id: 'entity-11',
          designId: '100k-12345',
          twoWindings: '{"designId":"100k-12345"}',
          fabrication:
              '{"tank":{"tank_L":900},"restOfVariables":{"designId":"100k-12345"}}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final showStatusButton = find.widgetWithText(FilledButton, 'Show Status');
    await tester.ensureVisible(showStatusButton);
    await tester.tap(showStatusButton);
    await tester.pumpAndSettle();

    expect(find.text('Fabrication 3D Generation Status'), findsOneWidget);
    expect(
      find.widgetWithText(
        ListTile,
        'Docker engine: preparing registries config',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, 'Executing remote combo builder...'),
      findsOneWidget,
    );
  });
}

Widget _buildScreen({
  required FabricationController controller,
  required DesignSummary summary,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FabricationScreen(
        routeDesignId: summary.id,
        initialDesignSummary: summary,
        controller: controller,
      ),
    ),
  );
}

class _FakeFabricationCalculationRepository
    implements FabricationCalculationRepository {
  @override
  Future<FabricationCalculationResult> calculate(
    FabricationCalculationRequest request,
  ) async {
    return FabricationCalculationResult.fromJson(const <String, dynamic>{
      'tank': <String, dynamic>{'tank_L': 900},
      'restOfVariables': <String, dynamic>{'designId': '100k-12345'},
    });
  }
}

class _FakeFabricationDesignRepository implements FabricationDesignRepository {
  @override
  Future<void> persistFabrication({
    required String entityId,
    required FabricationCalculationResult fabrication,
  }) async {}
}

class _FakeFabricationCadRepository implements FabricationCadRepository {
  @override
  Future<CadGenerationResult> generate3D(CadGenerationRequest request) async {
    return CadGenerationResult.fromJson(const <String, dynamic>{
      'message': 'fabrication generation requested',
    });
  }

  @override
  Future<StoredCadModel> loadModel(String designId) async {
    return StoredCadModel(bytes: Uint8List.fromList(<int>[]));
  }
}

class _FakeDrawingsStatusRepository implements DrawingsStatusRepository {
  _FakeDrawingsStatusRepository({List<DrawingsStatusEntry>? currentEntries})
    : currentEntries = currentEntries ?? <DrawingsStatusEntry>[];

  final List<DrawingsStatusEntry> currentEntries;

  @override
  Future<void> createStatus(DrawingsStatusCreateRequest request) async {}

  @override
  Future<void> deleteStatus(String entityId) async {}

  @override
  Future<PaginatedResponse<DrawingsStatusEntry>> fetchStatuses({
    required String designId,
    int offset = 0,
    int size = 30,
  }) async {
    return PaginatedResponse<DrawingsStatusEntry>(
      data: currentEntries
          .where((entry) => entry.designId == designId)
          .toList(growable: false),
      total: currentEntries.where((entry) => entry.designId == designId).length,
    );
  }
}
