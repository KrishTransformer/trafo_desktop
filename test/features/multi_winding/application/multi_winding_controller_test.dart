import 'package:flutter_test/flutter_test.dart';
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
    expect(calculation.request['lockedAttributes']['coreLock']['coreDia'], isTrue);
    expect(storage.designId, startsWith('500k-M'));
    expect(storage.design.textAt('designId'), storage.designId);
    expect(storage.design.readPath('lockedAttributes.coreLock.coreDia'), isTrue);
  });

  test('material selection applies the matching current density', () {
    final controller = _controller();

    controller.update('lVConductorMaterial', 'Al');
    controller.update('hVConductorMaterial', 'Cu');

    expect(controller.state.design.textAt('lvCurrentDensity'), '2.37');
    expect(controller.state.design.textAt('hvCurrentDensity'), '3.63');
  });

  test('calculation payload contains gaps for the selected configuration only', () {
    final controller = _controller();
    controller.update('windingConfiguration', '4_WDG_LV_HV_MAIN_FINE_OUTER');
    controller.update('coilDimensions.coreGap', '10');
    controller.update('coilDimensions.lvhvgap', '12');
    controller.update('multiCoilDimensions.gaps.hvMainToFineGap', '14');
    controller.update('multiCoilDimensions.gaps.fineToOuterGap', '16');
    controller.update('multiCoilDimensions.gaps.hvMainToCorseGap', '99');

    final payload = controller.buildPayload(controller.state.design);

    expect(payload['radialGaps'], <String, dynamic>{
      'coreToLv': '10',
      'lvToHv': '12',
      'hvToFine': '14',
      'fineToOuter': '16',
    });
  });

  test('parallel and conductor-size locks remain mutually exclusive', () {
    final controller = _controller();

    controller.toggleWindingLock('lv', 'conductorSizes');
    controller.toggleWindingLock('lv', 'noInParallel');

    expect(controller.state.design.readPath('lockedAttributes.lvWindings.conductorSizes'), isFalse);
    expect(controller.state.design.readPath('lockedAttributes.lvWindings.noInParallel'), isTrue);
  });

  test('calculated response values are retained without replacing submitted locks', () async {
    final storage = _DesignRepository();
    final controller = MultiWindingController(
      calculationRepository: _ResponseCalculationRepository(),
      designRepository: storage,
    );
    controller.update('kVA', '1000');
    controller.toggleWindingLock('lv', 'turnsPerPhase');

    await controller.calculate();

    expect(storage.design.textAt('coilDimensions.lvid'), '620');
    expect(storage.design.textAt('part2Windings.lv.turnsPerPhase'), '48');
    expect(storage.design.textAt('cost.capitalCost'), '125000');
    expect(storage.design.textAt('performance.noLoadLoss'), '750');
    expect(storage.design.textAt('multiCost.conductors.lv.totalCost'), '45000.0');
    expect(storage.design.readPath('lockedAttributes.lvWindings.turnsPerPhase'), isTrue);
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
  Future<String> createDesign({required String designId, required MultiWindingDesign design}) async {
    this.designId = designId;
    this.design = design;
    return 'entity-1';
  }
}

class _ResponseCalculationRepository implements MultiWindingCalculationRepository {
  @override
  Future<Map<String, dynamic>> calculate(Map<String, dynamic> request) async =>
      <String, dynamic>{
        'inputs': <String, dynamic>{'ratings': <String, dynamic>{'kVA': 1000}},
        'results': <String, dynamic>{
          'coilDimensions': <String, dynamic>{'lVID': 620},
          'noLoadLoss': 750,
          'lvWinding': <String, dynamic>{
            'turnsPerPhase': 48,
            'insulatedWeight': 50,
          },
          'tankAndOil': <String, dynamic>{'capitalCost': 125000},
        },
      };
}
