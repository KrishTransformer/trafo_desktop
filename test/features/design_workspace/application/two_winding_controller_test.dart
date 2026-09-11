import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/design_workspace/application/two_winding_controller.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/repositories/two_winding_calculation_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/repositories/two_winding_design_repository.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';

void main() {
  test(
    'new design discards saved data and uses the tf-web initial state',
    () async {
      final controller = TwoWindingController(
        routeId: 'new',
        calculationRepository: _FakeCalculationRepository(),
        designRepository: _FakeDesignRepository(),
      );
      addTearDown(controller.dispose);
      await controller.initialize(
        initialSummary: DesignSummary(
          id: 'old-design',
          designId: '500k-12345',
          createdAt: '2026-09-01',
          twoWindings: TwoWindingDesign.initial()
              .copyWithPath('kVA', '500')
              .copyWithPath('tank.tankLength', '1200')
              .copyWithPath('lockedAttributes.coreLock.coreDia', true)
              .copyWithPath('comments.coreToLvClrComment', 'Old note')
              .toJson(),
        ),
      );
      expect(
        controller.state.design.toJson(),
        TwoWindingDesign.initial().toJson(),
      );
      expect(controller.state.metadata.entityId, isEmpty);
      expect(controller.state.metadata.designId, isEmpty);
      expect(controller.state.metadata.createdAt, isEmpty);
      expect(controller.state.expandedMoreInfo, isFalse);
      expect(controller.state.activeComment, isEmpty);
    },
  );

  test('initialize loads an existing persisted two-winding payload', () async {
    final controller = TwoWindingController(
      routeId: 'entity-1',
      calculationRepository: _FakeCalculationRepository(),
      designRepository: _FakeDesignRepository(),
    );

    await controller.initialize(
      initialSummary: const DesignSummary(
        id: 'entity-1',
        designId: '100k-12345',
        twoWindings:
            '{"kVA":"100","vectorGroup":"Dyn11","core":{"coreMaterial":"CRGO"}}',
        createdAt: '2026-07-16T08:00:00.000Z',
      ),
    );

    expect(controller.state.metadata.entityId, 'entity-1');
    expect(controller.state.metadata.designId, '100k-12345');
    expect(controller.state.design.stringAt('kVA'), '100');
    expect(controller.state.design.stringAt('core.coreMaterial'), 'CRGO');
  });

  test('dry type applies the React temperature defaults', () async {
    final controller = TwoWindingController(
      routeId: 'new',
      calculationRepository: _FakeCalculationRepository(),
      designRepository: _FakeDesignRepository(),
    );
    await controller.initialize();

    controller.setField('dryType', true);

    expect(controller.state.design.boolAt('dryType'), isTrue);
    expect(controller.state.design.stringAt('dryTempClass'), 'CLASS_B');
    expect(controller.state.design.stringAt('windingTemp'), '70');

    controller.setField('dryTempClass', 'CLASS_H');

    expect(controller.state.design.stringAt('windingTemp'), '115');
  });

  test(
    'kVA heuristics set the same voltage and winding defaults as React',
    () async {
      final controller = TwoWindingController(
        routeId: 'new',
        calculationRepository: _FakeCalculationRepository(),
        designRepository: _FakeDesignRepository(),
      );
      await controller.initialize();

      controller.setField('kVA', '3000');

      expect(controller.state.design.stringAt('highVoltage'), '33000');
      expect(controller.state.design.stringAt('lowVoltage'), '11000');
      expect(controller.state.design.stringAt('hvWindingType'), 'DISC');
      expect(controller.state.design.stringAt('lvWindingType'), 'HELICAL');
      expect(controller.state.design.stringAt('fluxDensity'), '1.69');
    },
  );

  test(
    'calculate nulls unlocked locked-fields and creates a new design record',
    () async {
      final calculationRepository = _FakeCalculationRepository(
        response: TwoWindingDesign.initial()
            .copyWithPath('kVA', '100')
            .copyWithPath('core.coreMaterial', 'CRGO'),
      );
      final designRepository = _FakeDesignRepository();
      final controller = TwoWindingController(
        routeId: 'new',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
        random: Random(1),
      );
      await controller.initialize();

      controller.setField('innerWindings.turnsPerPhase', '12');
      controller.toggleLock('innerWindings.turnsPerPhase');
      controller.setField('core.coreDia', '220');
      controller.setField('frequency', null);
      controller.setField('topOilTemp', null);

      final success = await controller.calculate();

      expect(success, isTrue);
      expect(
        calculationRepository.lastRequest?.readPath(
          'innerWindings.turnsPerPhase',
        ),
        '12',
      );
      expect(
        calculationRepository.lastRequest?.readPath(
          'outerWindings.turnsPerPhase',
        ),
        isNull,
      );
      expect(
        calculationRepository.lastRequest?.readPath('core.coreDia'),
        isNull,
      );
      expect(calculationRepository.lastRequest?.readPath('frequency'), 50);
      expect(calculationRepository.lastRequest?.readPath('topOilTemp'), 50);
      expect(designRepository.createdDesignId, startsWith('100k-'));
      expect(
        designRepository.createdDesign?.stringAt('designId'),
        startsWith('100k-'),
      );
      expect(controller.state.metadata.designId, startsWith('100k-'));
    },
  );

  testWidgets(
    'queued hover comment updates do not notify after controller disposal',
    (tester) async {
      final controller = TwoWindingController(
        routeId: 'new',
        calculationRepository: _FakeCalculationRepository(),
        designRepository: _FakeDesignRepository(),
      );
      await controller.initialize();

      controller.showComment('tapStepComment');
      controller.dispose();

      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeCalculationRepository implements TwoWindingCalculationRepository {
  _FakeCalculationRepository({TwoWindingDesign? response})
    : response = response ?? TwoWindingDesign.initial();

  final TwoWindingDesign response;
  TwoWindingDesign? lastRequest;

  @override
  Future<TwoWindingDesign> calculate(TwoWindingDesign request) async {
    lastRequest = request;
    return response;
  }
}

class _FakeDesignRepository implements TwoWindingDesignRepository {
  String createdDesignId = '';
  TwoWindingDesign? createdDesign;

  @override
  Future<String> createDesign({
    required String designId,
    required TwoWindingDesign design,
  }) async {
    createdDesignId = designId;
    createdDesign = design;
    return 'entity-created-1';
  }
}
