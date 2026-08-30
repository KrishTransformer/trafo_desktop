import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/core_model/application/core_model_controller.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_request.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_result.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/repositories/core_calculation_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/repositories/core_design_repository.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';

void main() {
  test(
    'initialize backfills request fields from an existing persisted core payload',
    () async {
      final controller = CoreModelController(
        routeId: 'entity-1',
        calculationRepository: _FakeCoreCalculationRepository(),
        designRepository: _FakeCoreDesignRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-1',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","core":{"coreDia":210,"limbHt":640,"cenDist":420},"lvFormulas":{"revisedFluxDensity":1.652}}',
          core:
              '{"coreArea":1234,"coreWeight":456,"designedCoreArea":1111,"bldStacks":[{"stepNo":1,"width":120,"stack":90},{"stepNo":2,"width":80,"stack":45}]}',
        ),
      );

      expect(controller.state.designId, '100k-12345');
      expect(controller.state.request.coreDiameter, 210);
      expect(controller.state.request.minimumStepWidth, 80);
      expect(controller.state.request.numberOfSteps, 2);
      expect(controller.state.selectedStepNo, 1);
      expect(controller.state.editedWidth, '120');
      expect(controller.state.editedStack, '90');
    },
  );

  test(
    'initialize auto-calculates when two-winding core data exists but no core result is persisted',
    () async {
      final calculationRepository = _FakeCoreCalculationRepository(
        result: CoreCalculationResult.fromJson(<String, dynamic>{
          'coreArea': 1500,
          'bldStacks': <Map<String, dynamic>>[
            <String, dynamic>{'stepNo': 1, 'width': 90, 'stack': 70},
          ],
        }),
      );
      final designRepository = _FakeCoreDesignRepository();
      final controller = CoreModelController(
        routeId: 'entity-7',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-7',
          designId: '100k-77777',
          twoWindings:
              '{"core":{"coreDia":220,"limbHt":560,"cenDist":340},"lvFormulas":{"revisedFluxDensity":1.61}}',
        ),
      );

      expect(calculationRepository.requests, hasLength(1));
      expect(calculationRepository.requests.single.toJson(), <String, dynamic>{
        'coreDiameter': 220,
        'limbHt': 560,
        'cenDist': 340,
        'minimumStepWidth': 0,
        'numberOfSteps': 0,
        'fixtureStepWidth': null,
        'eCoreBladeType': 'CRUSI_3',
        'coreStackRequestList': <Map<String, dynamic>>[],
        'prevCoreStackRequestList': <Map<String, dynamic>>[],
      });
      expect(designRepository.persistedEntityIds, <String>['entity-7']);
      expect(controller.state.result?.coreArea, 1500);
    },
  );

  test(
    'initialize auto-calculates from a multi-winding design core',
    () async {
      final calculationRepository = _FakeCoreCalculationRepository(
        result: CoreCalculationResult.fromJson(<String, dynamic>{
          'coreArea': 1600,
          'bldStacks': <Map<String, dynamic>>[
            <String, dynamic>{'stepNo': 1, 'width': 100, 'stack': 80},
          ],
        }),
      );
      final designRepository = _FakeCoreDesignRepository();
      final controller = CoreModelController(
        routeId: 'entity-multi',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-multi',
          designId: 'multi-12345',
          designType: 'multi',
          multiWindings:
              '{"core":{"coreDia":310,"limbHt":780,"cenDist":510},"fluxDensity":1.7}',
        ),
      );

      expect(controller.state.hasDesignContext, isTrue);
      expect(controller.state.request.coreDiameter, 310);
      expect(controller.state.request.limbHt, 780);
      expect(controller.state.request.cenDist, 510);
      expect(controller.revisedFluxDensityText(), '1.7');
      expect(calculationRepository.requests, hasLength(1));
      expect(designRepository.persistedEntityIds, <String>['entity-multi']);
    },
  );

  test(
    'saveSelectedStep sends previous rows and the edited selected row payload',
    () async {
      final calculationRepository = _FakeCoreCalculationRepository(
        result: CoreCalculationResult.fromJson(<String, dynamic>{
          'coreArea': 1900,
          'bldStacks': <Map<String, dynamic>>[
            <String, dynamic>{'stepNo': 1, 'width': 100, 'stack': 70},
            <String, dynamic>{'stepNo': 2, 'width': 90, 'stack': 50},
            <String, dynamic>{'stepNo': 3, 'width': 70, 'stack': 30},
          ],
        }),
      );
      final designRepository = _FakeCoreDesignRepository();
      final controller = CoreModelController(
        routeId: 'entity-9',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-9',
          designId: '200k-99999',
          twoWindings:
              '{"core":{"coreDia":240,"limbHt":620,"cenDist":410},"lvFormulas":{"revisedFluxDensity":1.58}}',
          core:
              '{"coreArea":1700,"bldStacks":[{"stepNo":1,"width":100,"stack":70},{"stepNo":2,"width":80,"stack":40},{"stepNo":3,"width":60,"stack":20}]}',
        ),
      );

      controller.selectStep(3);
      controller.updateEditedWidth('65');
      controller.updateEditedStack('25');

      final saved = await controller.saveSelectedStep();

      expect(saved, isTrue);
      final request = calculationRepository.requests.last;
      expect(
        request.toJson()['prevCoreStackRequestList'],
        <Map<String, dynamic>>[
          <String, dynamic>{'stepNo': 1, 'width': 100, 'stack': 70},
          <String, dynamic>{'stepNo': 2, 'width': 80, 'stack': 40},
        ],
      );
      expect(request.toJson()['coreStackRequestList'], <Map<String, dynamic>>[
        <String, dynamic>{'stepNo': 3, 'width': '65', 'stack': '25'},
      ]);
      expect(designRepository.persistedEntityIds.last, 'entity-9');
    },
  );

  test('calculate without saved design context surfaces an error', () async {
    final controller = CoreModelController(
      routeId: '',
      calculationRepository: _FakeCoreCalculationRepository(),
      designRepository: _FakeCoreDesignRepository(),
    );

    await controller.initialize();
    final calculated = await controller.calculate();

    expect(calculated, isFalse);
    expect(
      controller.state.errorMessage,
      'Open the core model from a saved design before calculating.',
    );
  });
}

class _FakeCoreCalculationRepository implements CoreCalculationRepository {
  _FakeCoreCalculationRepository({CoreCalculationResult? result})
    : result =
          result ??
          CoreCalculationResult.fromJson(const <String, dynamic>{
            'coreArea': 0,
            'bldStacks': <Never>[],
          });

  final CoreCalculationResult result;
  final List<CoreCalculationRequest> requests = <CoreCalculationRequest>[];

  @override
  Future<CoreCalculationResult> calculate(
    CoreCalculationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

class _FakeCoreDesignRepository implements CoreDesignRepository {
  final List<String> persistedEntityIds = <String>[];
  final List<CoreCalculationResult> persistedResults =
      <CoreCalculationResult>[];

  @override
  Future<void> persistCore({
    required String entityId,
    required CoreCalculationResult core,
  }) async {
    persistedEntityIds.add(entityId);
    persistedResults.add(core);
  }
}
