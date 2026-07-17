import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/fabrication/application/fabrication_controller.dart';
import 'package:trafo_desktop/src/features/fabrication/application/fabrication_state.dart';
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
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';

void main() {
  test(
    'initialize seeds fabrication form values from two-winding and core',
    () async {
      final controller = FabricationController(
        routeId: 'new',
        calculationRepository: _FakeFabricationCalculationRepository(),
        designRepository: _FakeFabricationDesignRepository(),
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: '',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","kVA":100,"highVoltage":11000,"lowVoltage":433,"vectorGroup":"Dyn11","core":{"coreDia":210,"limbHt":640,"cenDist":420},"tank":{"tankLength":1000,"tankWidth":700,"tankHeight":900,"tankWallThickness":6,"tankBottomThickness":8,"frameThickness":10,"tankLidThickness":5},"tankAndOilFormulas":{"transformerWeight":3450,"radiatorHeight":1200,"radiatorWidth":520,"noOfFinsPerRadiator":18,"noOfRadiators":4,"hvBushingCurrent":12,"lvBushingCurrent":145,"conservatorCapacity":200,"conservatorDia":320,"conservatorLength":1600},"coilDimensions":{"lvid":240,"lvod":300,"hvid":340,"hvod":420},"innerWindings":{"windingLength":550,"turnsPerPhase":18},"outerWindings":{"windingLength":680}}',
          core: '{"numberOfSteps":5}',
        ),
      );

      expect(
        controller.state.formData.stringAt('restOfVariables.designId'),
        '100k-12345',
      );
      expect(
        controller.state.formData.stringAt('restOfVariables.limb_Nos'),
        '5',
      );
      expect(controller.state.formData.stringAt('tank.tank_L'), '1000');
      expect(
        controller.state.formData.stringAt('radiator.radiator_Left_Nos'),
        '2.0',
      );
      expect(controller.state.formData.stringAt('hvb.hvb_Amp'), '12');
      expect(controller.state.formData.stringAt('lv.lv_ID'), '240');
      expect(controller.state.formData.stringAt('hv.hv_Wdg_L'), '680');
    },
  );

  test(
    'initialize auto-calculates when no fabrication result is persisted',
    () async {
      final calculationRepository = _FakeFabricationCalculationRepository(
        result: FabricationCalculationResult.fromJson(<String, dynamic>{
          'tank': <String, dynamic>{'tank_L': 1111},
          'restOfVariables': <String, dynamic>{'designId': '100k-77777'},
        }),
      );
      final designRepository = _FakeFabricationDesignRepository();
      final controller = FabricationController(
        routeId: 'entity-7',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-7',
          designId: '100k-77777',
          twoWindings:
              '{"designId":"100k-77777","kVA":100,"highVoltage":11000,"lowVoltage":433,"vectorGroup":"Dyn11","core":{"coreDia":220,"limbHt":560,"cenDist":340},"tank":{"tankLength":960,"tankWidth":680,"tankHeight":840,"tankWallThickness":6,"tankBottomThickness":8,"frameThickness":10,"tankLidThickness":5},"tankAndOilFormulas":{"transformerWeight":3100,"radiatorHeight":1100,"radiatorWidth":500,"noOfFinsPerRadiator":16,"noOfRadiators":4,"hvBushingCurrent":11,"lvBushingCurrent":140,"conservatorCapacity":180,"conservatorDia":300,"conservatorLength":1500},"coilDimensions":{"lvid":210,"lvod":290,"hvid":330,"hvod":410},"innerWindings":{"windingLength":520,"turnsPerPhase":16},"outerWindings":{"windingLength":650},"hvFormulas":{"hvCurrentPerPhase":10,"turnsPerTap":[1],"tapVoltages":[100],"tapCurrent":[10]},"lvFormulas":{"lvCurrentPerPhase":120},"commonFormulas":{"ek":4},"tapStepsPercent":2.5,"tapStepsPositive":2,"tapStepsNegative":2}',
        ),
      );

      expect(calculationRepository.requests, hasLength(1));
      expect(designRepository.persistedEntityIds, <String>['entity-7']);
      expect(controller.state.result?.stringAt('tank.tank_L'), '1111');
      expect(controller.state.hasCalculatedSinceLastGenerate, isTrue);
    },
  );

  test(
    'initialize restores persisted fabrication instead of reseeding it',
    () async {
      final calculationRepository = _FakeFabricationCalculationRepository();
      final controller = FabricationController(
        routeId: 'entity-3',
        calculationRepository: calculationRepository,
        designRepository: _FakeFabricationDesignRepository(),
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-3',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","tank":{"tankLength":1000},"highVoltage":11000,"lowVoltage":433}',
          fabrication:
              '{"tank":{"tank_L":900},"hvb":{"hvb_Pos":"tank"},"restOfVariables":{"designId":"100k-12345"}}',
        ),
      );

      expect(calculationRepository.requests, isEmpty);
      expect(controller.state.formData.stringAt('tank.tank_L'), '900');
      expect(controller.state.formData.stringAt('hvb.hvb_Pos'), 'tank');
    },
  );

  test('updateField preserves the coupled fabrication behaviors', () async {
    final controller = FabricationController(
      routeId: 'new',
      calculationRepository: _FakeFabricationCalculationRepository(),
      designRepository: _FakeFabricationDesignRepository(),
      cadRepository: _FakeFabricationCadRepository(),
      drawingsStatusRepository: _FakeDrawingsStatusRepository(),
    );

    await controller.initialize(
      initialSummary: const DesignSummary(
        id: '',
        designId: '100k-12345',
        twoWindings: '{"designId":"100k-12345"}',
      ),
    );

    controller.updateField('gorPipe.buchholz_Relay', true);
    controller.updateField('hvcb.hvcb', true);
    controller.updateField('lvcb.lvcb', 'true');

    expect(controller.state.formData.boolAt('gorPipe.buchholz_Relay'), isTrue);
    expect(controller.state.formData.boolAt('gorPipe.single_Valve'), isTrue);
    expect(controller.state.formData.boolAt('gorPipe.valve_Type1'), isTrue);
    expect(controller.state.formData.stringAt('hvb.hvb_Pos'), 'tank');
    expect(controller.state.formData.stringAt('lvb.lvb_Pos'), 'tank');
    expect(controller.state.hasEditedSinceLastGenerate, isTrue);
  });

  test(
    'calculate sends the flattened fabrication payload and persists the result',
    () async {
      final calculationRepository = _FakeFabricationCalculationRepository(
        result: FabricationCalculationResult.fromJson(<String, dynamic>{
          'tank': <String, dynamic>{'tank_L': 1200},
          'restOfVariables': <String, dynamic>{'designId': '100k-12345'},
        }),
      );
      final designRepository = _FakeFabricationDesignRepository();
      final controller = FabricationController(
        routeId: 'entity-9',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-9',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","kVA":100,"highVoltage":11000,"lowVoltage":433,"vectorGroup":"Dyn11","frequency":50,"topOilTemp":55,"windingTemp":65,"hvImpulseVoltage":75,"hvTestVoltage":28,"lvImpulseVoltage":0,"lvTestVoltage":3,"lossesAt50Percent":111,"lossesAt100Percent":222,"core":{"coreDia":210,"limbHt":640,"cenDist":420},"tank":{"tankLength":1000,"tankWidth":700,"tankHeight":900,"tankWallThickness":6,"tankBottomThickness":8,"frameThickness":10,"tankLidThickness":5},"tankAndOilFormulas":{"transformerWeight":3450,"radiatorHeight":1200,"radiatorWidth":520,"noOfFinsPerRadiator":18,"noOfRadiators":4,"hvBushingCurrent":12,"lvBushingCurrent":145,"conservatorCapacity":200,"conservatorDia":320,"conservatorLength":1600,"weightsOfActivePart":1200,"oilWeight":500,"totalOil":650,"weightOfTankAndAcc":900},"coilDimensions":{"lvid":240,"lvod":300,"hvid":340,"hvod":420},"innerWindings":{"windingLength":550,"turnsPerPhase":18},"outerWindings":{"windingLength":680},"hvFormulas":{"hvCurrentPerPhase":10.5,"turnsPerTap":[1,2],"tapVoltages":[100,101],"tapCurrent":[10.5,10.7]},"lvFormulas":{"lvCurrentPerPhase":145},"commonFormulas":{"ek":4.5},"tapStepsPercent":2.5,"tapStepsPositive":2,"tapStepsNegative":2}',
          fabrication:
              '{"tank":{"tank_L":900},"hvb":{"hvb_Pos":"tank","hvb_Volt":11000,"hvb_Amp":15},"lvb":{"lvb_Pos":"lid","lvb_Volt":433,"lvb_Amp":140},"hvcb":{"hvcb":true},"lvcb":{"lvcb":false},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"smpl_Vlv":{"smpl_Vlv":true,"smpl_Vlv_Nos":1},"fill_Vlv":{"fill_Vlv":true},"roller":{"roller":true,"roller_Type":"std","roller_Guage":"wide"},"gorPipe":{"buchholz_Relay":true,"single_Valve":true,"valve_Type1":true},"mog":{"mog":true,"mog_Tlt_Ang":"30"},"exp_Vent":{"exp_Vent":true,"exp_Vent_ID":"E1","exp_Vent_With_OI":false},"lid_LiftLug":{"lid_LiftLug":true,"lid_LiftLug_Thick":"12"},"thermoPkt":{"thermoPkt1":true,"thermoPkt2":false},"bot_Chnl":{"isRoller":false},"radiator":{"radiator_Vlv":"rv1"},"restOfVariables":{"designId":"100k-12345","prv":"PRV-1","mbox":"MBOX","mbox_Inst_Nos":"2","thrmo_Syphn":"TS-1"}}',
        ),
      );

      final calculated = await controller.calculate();

      expect(calculated, isTrue);
      final request = calculationRepository.requests.single.toJson();
      expect(request['designId'], '100k-12345');
      expect(request['limb_Nos'], 3);
      expect(request['tank_L'], 1000);
      expect(request['hvb_Pos'], 'tank');
      expect(request['hvcb'], true);
      expect(request['printouts'], isA<Map<String, dynamic>>());
      expect(request['isOCTC'], isTrue);
      expect(designRepository.persistedEntityIds.last, 'entity-9');
      expect(controller.state.result?.stringAt('tank.tank_L'), '1200');
    },
  );

  test(
    'generate3D deletes prior statuses, sends merged payload, and creates a requested status',
    () async {
      final cadRepository = _FakeFabricationCadRepository(
        generateResult: CadGenerationResult.fromJson(const <String, dynamic>{
          'message': 'fabrication generation requested',
        }),
      );
      final statusRepository = _FakeDrawingsStatusRepository(
        currentEntries: <DrawingsStatusEntry>[
          DrawingsStatusEntry.fromJson(const <String, dynamic>{
            'id': 'status-1',
            'designId': '100k-12345',
            'message': 'Starting',
            'status': 'Processing',
            'createdAt': '2026-07-16T09:00:00.000Z',
          }),
          DrawingsStatusEntry.fromJson(const <String, dynamic>{
            'id': 'status-2',
            'designId': '100k-12345',
            'message': 'Queued',
            'status': 'Processing',
            'createdAt': '2026-07-16T09:01:00.000Z',
          }),
        ],
      );
      final controller = FabricationController(
        routeId: 'entity-11',
        calculationRepository: _FakeFabricationCalculationRepository(),
        designRepository: _FakeFabricationDesignRepository(),
        cadRepository: cadRepository,
        drawingsStatusRepository: statusRepository,
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-11',
          designId: '100k-12345',
          twoWindings: '{"designId":"100k-12345"}',
          fabrication:
              '{"tank":{"tank_L":900},"hvb":{"hvb_Pos":"tank"},"restOfVariables":{"designId":"100k-12345"}}',
        ),
      );

      final generated = await controller.generate3D();

      expect(generated, isTrue);
      expect(cadRepository.requests, hasLength(1));
      expect(cadRepository.requests.single.fileName, '100k-12345');
      expect(cadRepository.requests.single.payload['tank_L'], 900);
      expect(cadRepository.requests.single.payload['hvb_Pos'], 'tank');
      expect(statusRepository.deletedIds, <String>['status-1', 'status-2']);
      expect(statusRepository.createdRequests, hasLength(1));
      expect(
        statusRepository.createdRequests.single.toJson(),
        <String, dynamic>{
          'designId': '100k-12345',
          'message': 'Generate 3D Requested',
          'status': 'Success',
        },
      );
      expect(
        controller.state.cadGenerationMessage,
        'fabrication generation requested',
      );
      expect(controller.state.hasCalculatedSinceLastGenerate, isFalse);
      expect(controller.state.hasEditedSinceLastGenerate, isFalse);
    },
  );

  test(
    'status gating switches between Generate 3D and Show Status based on timeline state',
    () async {
      final recentCreatedAt = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();
      final expiredCreatedAt = DateTime.now()
          .subtract(const Duration(minutes: 50))
          .toUtc()
          .toIso8601String();

      final pendingController = FabricationController(
        routeId: 'new',
        calculationRepository: _FakeFabricationCalculationRepository(),
        designRepository: _FakeFabricationDesignRepository(),
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(
          currentEntries: <DrawingsStatusEntry>[
            DrawingsStatusEntry.fromJson(<String, dynamic>{
              'id': 'status-pending',
              'designId': '100k-12345',
              'message': 'Docker engine: preparing registries config',
              'status': 'Processing',
              'createdAt': recentCreatedAt,
            }),
          ],
        ),
      );
      await pendingController.initialize(
        initialSummary: const DesignSummary(
          id: '',
          designId: '100k-12345',
          twoWindings: '{"designId":"100k-12345"}',
          fabrication:
              '{"tank":{"tank_L":900},"restOfVariables":{"designId":"100k-12345"}}',
        ),
      );

      expect(pendingController.state.shouldShowStatusButton, isTrue);
      expect(pendingController.state.canGenerate3D, isFalse);
      expect(
        pendingController.state.cadPrimaryAction,
        FabricationCadAction.showStatus,
      );

      final expiredController = FabricationController(
        routeId: 'new',
        calculationRepository: _FakeFabricationCalculationRepository(),
        designRepository: _FakeFabricationDesignRepository(),
        cadRepository: _FakeFabricationCadRepository(),
        drawingsStatusRepository: _FakeDrawingsStatusRepository(
          currentEntries: <DrawingsStatusEntry>[
            DrawingsStatusEntry.fromJson(<String, dynamic>{
              'id': 'status-old',
              'designId': '100k-12345',
              'message': 'Queued',
              'status': 'Processing',
              'createdAt': expiredCreatedAt,
            }),
          ],
        ),
      );
      await expiredController.initialize(
        initialSummary: const DesignSummary(
          id: '',
          designId: '100k-12345',
          twoWindings: '{"designId":"100k-12345"}',
          fabrication:
              '{"tank":{"tank_L":900},"restOfVariables":{"designId":"100k-12345"}}',
        ),
      );

      expect(expiredController.state.shouldShowStatusButton, isFalse);
      expect(expiredController.state.canGenerate3D, isTrue);
      expect(
        expiredController.state.cadPrimaryAction,
        FabricationCadAction.generate3d,
      );
    },
  );
}

class _FakeFabricationCalculationRepository
    implements FabricationCalculationRepository {
  _FakeFabricationCalculationRepository({FabricationCalculationResult? result})
    : result =
          result ??
          FabricationCalculationResult.fromJson(const <String, dynamic>{
            'tank': <String, dynamic>{'tank_L': 0},
            'restOfVariables': <String, dynamic>{'designId': ''},
          });

  final FabricationCalculationResult result;
  final List<FabricationCalculationRequest> requests =
      <FabricationCalculationRequest>[];

  @override
  Future<FabricationCalculationResult> calculate(
    FabricationCalculationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

class _FakeFabricationDesignRepository implements FabricationDesignRepository {
  final List<String> persistedEntityIds = <String>[];
  final List<FabricationCalculationResult> persistedResults =
      <FabricationCalculationResult>[];

  @override
  Future<void> persistFabrication({
    required String entityId,
    required FabricationCalculationResult fabrication,
  }) async {
    persistedEntityIds.add(entityId);
    persistedResults.add(fabrication);
  }
}

class _FakeFabricationCadRepository implements FabricationCadRepository {
  _FakeFabricationCadRepository({
    CadGenerationResult? generateResult,
    StoredCadModel? storedCadModel,
  }) : generateResult =
           generateResult ??
           CadGenerationResult.fromJson(const <String, dynamic>{'message': ''}),
       storedCadModel =
           storedCadModel ?? StoredCadModel(bytes: Uint8List.fromList(<int>[]));

  final CadGenerationResult generateResult;
  final StoredCadModel storedCadModel;
  final List<CadGenerationRequest> requests = <CadGenerationRequest>[];
  final List<String> loadedDesignIds = <String>[];

  @override
  Future<CadGenerationResult> generate3D(CadGenerationRequest request) async {
    requests.add(request);
    return generateResult;
  }

  @override
  Future<StoredCadModel> loadModel(String designId) async {
    loadedDesignIds.add(designId);
    return storedCadModel;
  }
}

class _FakeDrawingsStatusRepository implements DrawingsStatusRepository {
  _FakeDrawingsStatusRepository({List<DrawingsStatusEntry>? currentEntries})
    : currentEntries = currentEntries ?? <DrawingsStatusEntry>[];

  final List<DrawingsStatusEntry> currentEntries;
  final List<String> deletedIds = <String>[];
  final List<DrawingsStatusCreateRequest> createdRequests =
      <DrawingsStatusCreateRequest>[];
  final List<String> fetchDesignIds = <String>[];

  @override
  Future<void> createStatus(DrawingsStatusCreateRequest request) async {
    createdRequests.add(request);
    currentEntries.add(
      DrawingsStatusEntry(
        id: 'generated-${createdRequests.length}',
        designId: request.designId,
        message: request.message,
        status: request.status,
        createdAt: '2026-07-16T09:05:00.000Z',
      ),
    );
  }

  @override
  Future<void> deleteStatus(String entityId) async {
    deletedIds.add(entityId);
    currentEntries.removeWhere((entry) => entry.id == entityId);
  }

  @override
  Future<PaginatedResponse<DrawingsStatusEntry>> fetchStatuses({
    required String designId,
    int offset = 0,
    int size = 30,
  }) async {
    fetchDesignIds.add(designId);
    return PaginatedResponse<DrawingsStatusEntry>(
      data: currentEntries
          .where((entry) => entry.designId == designId)
          .toList(growable: false),
      total: currentEntries.where((entry) => entry.designId == designId).length,
    );
  }
}
