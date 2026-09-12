import 'package:flutter_test/flutter_test.dart';
import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/features/multi_winding/application/multi_winding_controller.dart';
import 'package:trafo_desktop/src/features/multi_winding/domain/models/multi_winding_design.dart';
import 'package:trafo_desktop/src/features/multi_winding/domain/repositories/multi_winding_repositories.dart';

void main() {
  test('calculate sends locks and persists a multi-winding design', () async {
    final calculation = _CalculationRepository();
    final storage = _DesignRepository();
    final controller = MultiWindingController(
      calculationRepository: calculation,
      designRepository: storage,
    );
    controller.update('kVA', '500');
    controller.update('core.coreDia', '220');
    controller.toggleCoreLock('coreDia');

    final succeeded = await controller.calculate();

    expect(succeeded, isTrue);
    expect(
      calculation.request['lockedAttributes']['coreLock']['coreDia'],
      isTrue,
    );
    expect(storage.designId, startsWith('500k-M'));
    expect(storage.design.textAt('designId'), storage.designId);
    expect(
      storage.design.readPath('lockedAttributes.coreLock.coreDia'),
      isTrue,
    );
  });

  test('material selection applies the matching current density', () {
    final controller = _controller();

    controller.update('lVConductorMaterial', 'Al');
    controller.update('hVConductorMaterial', 'Cu');

    expect(controller.state.design.textAt('lvCurrentDensity'), '2.37');
    expect(controller.state.design.textAt('hvCurrentDensity'), '3.63');
  });

  test(
    'calculation payload contains gaps for the selected configuration only',
    () {
      final controller = _controller();
      controller.update('windingConfiguration', '4_WDG_LV_HV_MAIN_FINE_OUTER');
      controller.update('coilDimensions.coreGap', '10');
      controller.update('coilDimensions.lvhvgap', '12');
      controller.update('multiCoilDimensions.gaps.hvMainToFineGap', '14');
      controller.update('multiCoilDimensions.gaps.fineToOuterGap', '16');
      controller.update('multiCoilDimensions.gaps.hvMainToCorseGap', '99');

      final payload = controller.buildPayload(controller.state.design);

      expect(payload['radialGaps'], <String, dynamic>{
        'coreToLv': 10.0,
        'lvToHv': 12.0,
        'hvToFine': 14.0,
        'fineToOuter': 16.0,
      });
      expect(payload['coreToLv'], 10.0);
      expect(payload['hvToFine'], 14.0);
    },
  );

  test('payload sends frequency, temperatures, core, tank, and materials', () {
    final controller = _controller();
    expect(controller.buildPayload(controller.state.design)['frequency'], 50.0);
    controller.update('kVA', '25000');
    controller.update('frequency', '60');
    controller.update('topOilTemp', '31.6');
    controller.update('buildFactor', '1.3');
    controller.update('core.coreDia', '640');
    controller.update('core.coreMaterial', 'NipM4');
    controller.update('core.coreType', 'PRIME');
    controller.update('tank.tankLoss', '10000');
    controller.update('tank.wdgToTankGap', '130');
    controller.update('part2Windings.lv.noOfLayers', '3.75');
    controller.update('lVConductorMaterial', 'Cu');
    controller.toggleCoreLock('coreDia');

    final payload = controller.buildPayload(controller.state.design);

    expect(payload['frequency'], 60.0);
    expect(payload['topOilTemp'], 31.6);
    expect(payload['buildFactor'], 1.3);
    expect(payload['tankLoss'], 10000.0);
    expect(payload['core'], containsPair('coreDia', 640));
    expect(payload['core'], containsPair('coreMaterial', 'NipM4'));
    expect(payload['core'], containsPair('coreType', 'PRIME'));
    expect(payload['tank'], containsPair('wdgToTankGap', 130.0));
    expect(payload['lvConductorMaterial'], 'COPPER');
    expect(payload['lvWindings']['noOfLayers'], 3.75);
  });

  test('null legacy frequency and oil temperature receive defaults', () {
    final design = MultiWindingDesign.fromJson(<String, dynamic>{
      'frequency': null,
      'topOilTemp': null,
    });

    expect(design.textAt('frequency'), '50');
    expect(design.textAt('topOilTemp'), '50');
    expect(_controller().buildPayload(design)['topOilTemp'], 50.0);
  });

  test('parallel and conductor-size locks remain mutually exclusive', () {
    final controller = _controller();

    controller.toggleWindingLock('lv', 'conductorSizes');
    controller.toggleWindingLock('lv', 'noInParallel');

    expect(
      controller.state.design.readPath(
        'lockedAttributes.lvWindings.conductorSizes',
      ),
      isFalse,
    );
    expect(
      controller.state.design.readPath(
        'lockedAttributes.lvWindings.noInParallel',
      ),
      isTrue,
    );
  });

  test(
    'calculated response values are retained without replacing submitted locks',
    () async {
      final storage = _DesignRepository();
      final controller = MultiWindingController(
        calculationRepository: _ResponseCalculationRepository(),
        designRepository: storage,
      );
      controller.update('kVA', '1000');
      controller.toggleWindingLock('lv', 'turnsPerPhase');

      await controller.calculate();

      expect(storage.design.textAt('coilDimensions.lvid'), '620');
      expect(
        storage.design.textAt('windingConfiguration'),
        '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER',
      );
      expect(storage.design.textAt('lowVoltage'), '6351');
      expect(storage.design.textAt('highVoltage'), '31351');
      expect(storage.design.textAt('buildFactor'), '1.25');
      expect(storage.design.textAt('ez'), '5.99');
      expect(storage.design.textAt('part2Windings.lv.turnsPerPhase'), '48');
      expect(
        storage.design.textAt('part2Windings.lv.weightBareInsulated'),
        '45 / 50',
      );
      expect(storage.design.textAt('cost.capitalCost'), '125000');
      expect(
        storage.design.textAt('tank.tankDimension'),
        '1570 L X 610 W X 1165 H mm',
      );
      expect(
        storage.design.textAt('tankAndOilFormulas.coolingStatement'),
        'L X W = 800 X 520 : 12 X 93',
      );
      expect(
        storage.design.textAt('tankAndOilFormulas.totalSteelWeight'),
        '410',
      );
      expect(storage.design.textAt('performance.noLoadLoss'), '750');
      expect(storage.design.textAt('performance.impedance'), '5.99');
      expect(storage.design.textAt('revisedVoltsPerTurn'), '9.125');
      expect(storage.design.textAt('revisedFluxDensity'), '1.6288');
      expect(storage.design.textAt('performance.kW55'), '42.5');
      expect(
        storage.design.textAt('multiCost.conductors.lv.totalCost'),
        '42500.0',
      );
      expect(
        storage.design.readPath('lockedAttributes.lvWindings.turnsPerPhase'),
        isTrue,
      );
    },
  );

  test('calculated values are shown even when saving fails', () async {
    final controller = MultiWindingController(
      calculationRepository: _ResponseCalculationRepository(),
      designRepository: _FailingDesignRepository(),
    );
    controller.update('kVA', '1000');

    final succeeded = await controller.calculate();

    expect(succeeded, isFalse);
    expect(controller.state.isCalculating, isFalse);
    expect(controller.state.design.textAt('coilDimensions.lvid'), '620');
    expect(controller.state.design.textAt('performance.noLoadLoss'), '750');
    expect(controller.state.design.textAt('cost.capitalCost'), '125000');
    expect(
      controller.state.errorMessage,
      contains('Calculated values are shown'),
    );
  });
}

MultiWindingController _controller() => MultiWindingController(
  calculationRepository: _CalculationRepository(),
  designRepository: _DesignRepository(),
);

class _CalculationRepository implements MultiWindingCalculationRepository {
  Map<String, dynamic> request = <String, dynamic>{};
  @override
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> request) async {
    this.request = request;
    return <String, dynamic>{'kVA': 500, 'results': <String, dynamic>{}};
  }
}

class _DesignRepository implements MultiWindingDesignRepository {
  String designId = '';
  MultiWindingDesign design = MultiWindingDesign.initial();
  @override
  Future<String> createDesign({
    required String designId,
    required MultiWindingDesign design,
  }) async {
    this.designId = designId;
    this.design = design;
    return 'entity-1';
  }
}

class _FailingDesignRepository implements MultiWindingDesignRepository {
  @override
  Future<String> createDesign({
    required String designId,
    required MultiWindingDesign design,
  }) {
    throw const ApiException(
      type: ApiExceptionType.server,
      message: 'Save failed.',
    );
  }
}

class _ResponseCalculationRepository
    implements MultiWindingCalculationRepository {
  @override
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> request) async =>
      <String, dynamic>{
        'selectedCode': '5_WDG',
        'inputs': <String, dynamic>{
          'ratings': <String, dynamic>{
            'kVA': 1000,
            'lowVoltage': 11000,
            'highVoltage': 33000,
            'frequency': 50,
            'fluxDensity': 1.7333,
            'kValue': 0.45,
          },
          'vectorGroup': 'Dyn11',
          'windingModels': <String, dynamic>{
            'lv': <String, dynamic>{'turnsPerPhase': 48},
          },
        },
        'results': <String, dynamic>{
          'phaseVoltages': <String, dynamic>{'lv': 6351, 'hvMain': 31351},
          'common': <String, dynamic>{'buildFactor': 1.25, 'ek': 5.99},
          'impedance': <String, dynamic>{'ek': 5.99},
          'coilDimensions': <String, dynamic>{'lVID': 620},
          'noLoadLoss': 750,
          'revisedVoltsPerTurn': 9.125,
          'revisedFluxDensity': 1.6288,
          'lvWinding': <String, dynamic>{
            'turnsPerPhase': 48,
            'bareWeight': 45,
            'insulatedWeight': 50,
          },
          'tankAndOil': <String, dynamic>{
            'capitalCost': 125000,
            'totalSteelWeight': 410,
            'kw55': 42.5,
            'tankDimension': '1570 L X 610 W X 1165 H mm',
            'coolingStatement': 'L X W = 800 X 520 : 12 X 93',
          },
          'ez': <String, dynamic>{'value': 5.99, 'limit': 5},
        },
      };
}
