import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/features/files/application/files_controller.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_line_item.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_list_response.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_request.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/files_design_repository.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/files_lom_repository.dart';
import 'package:trafo_desktop/src/features/files/domain/repositories/lom_material_repository.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';

void main() {
  test(
    'initialize loads materials, generates lom rows, and decorates display rows',
    () async {
      final lomRepository = _FakeFilesLomRepository(
        response: <LomLineItem>[
          LomLineItem.fromJson(<String, dynamic>{
            'description': 'Lamination',
            'specification': 'CRGO',
            'unit': 'kg',
            'quantity': 125.5,
            'rate': 220,
            'cost': 27610,
          }),
        ],
      );
      final controller = FilesController(
        routeId: 'entity-21',
        lomRepository: lomRepository,
        lomMaterialRepository: _FakeLomMaterialRepository(),
        designRepository: _FakeFilesDesignRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-21',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","vectorGroup":"Dyn11","isOLTC":false,"isCSP":false,"core":{"coreWeight":880},"hvFormulas":{"hvProcurementWeight":45},"lvFormulas":{"lvProcurementWeight":55},"tankAndOilFormulas":{"hvConnectionWeight":12,"lvConnectionWeight":14,"insulationWeight":18,"totalOil":320,"weightOfTankAndAcc":900,"totalRadiatorWeight":410,"channelWeight":22}}',
          fabrication:
              '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true,"fill_Vlv_Nos":1},"smpl_Vlv":{"smpl_Vlv":false,"smpl_Vlv_Nos":0},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
        ),
      );

      expect(controller.state.materials, hasLength(39));
      expect(lomRepository.requests, hasLength(1));
      expect(
        lomRepository.requests.single.toJson()['lomBooleans'],
        containsPair('hvBushing', true),
      );
      expect(
        lomRepository.requests.single.toJson()['lomQuantity'],
        containsPair('lamination', 880),
      );
      expect(
        lomRepository.requests.single.toJson()['lomRate'],
        containsPair('lamination', 220.0),
      );
      expect(controller.state.displayRows.single.numberAt('index'), 0);
      expect(controller.state.displayRows.single.boolAt('isNew'), isFalse);
      expect(
        controller.state.displayRows.single.stringAt('rateKey'),
        'lamination',
      );
      expect(controller.state.totalCost, 27610);
    },
  );

  test('initialize generates a LOM from a multi-winding design', () async {
    final lomRepository = _FakeFilesLomRepository();
    final controller = FilesController(
      routeId: 'entity-multi',
      lomRepository: lomRepository,
      lomMaterialRepository: _FakeLomMaterialRepository(),
      designRepository: _FakeFilesDesignRepository(),
    );

    await controller.initialize(
      initialSummary: const DesignSummary(
        id: 'entity-multi',
        designId: 'multi-12345',
        designType: 'multi',
        multiWindings:
            '{"vectorGroup":"Dyn11","core":{"coreWeight":950},"multiCost":{"conductors":{"lv":{"weight":60},"hvMain":{"weight":48}}},"tankAndOilFormulas":{"hvConnectionWeight":15,"lvConnectionWeight":16,"insulationWeight":20,"totalOil":340,"weightOfTankAndAcc":930,"totalRadiatorWeight":440,"channelWeight":25}}',
        fabrication:
            '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true},"smpl_Vlv":{"smpl_Vlv":false},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
      ),
    );

    expect(controller.state.hasGenerationContext, isTrue);
    expect(lomRepository.requests, hasLength(1));
    final request = lomRepository.requests.single.toJson();
    expect(request['lomQuantity'], containsPair('lamination', 950));
    expect(request['lomQuantity'], containsPair('hvConductor', 48));
    expect(request['lomQuantity'], containsPair('lvConductor', 60));
  });

  test(
    'updateRate on a generated row stores an override and re-fetches the lom',
    () async {
      final lomRepository = _FakeFilesLomRepository(
        responseSequence: <List<LomLineItem>>[
          <LomLineItem>[
            LomLineItem.fromJson(<String, dynamic>{
              'description': 'Lamination',
              'specification': 'CRGO',
              'unit': 'kg',
              'quantity': 100,
              'rate': 220,
              'cost': 22000,
            }),
          ],
          <LomLineItem>[
            LomLineItem.fromJson(<String, dynamic>{
              'description': 'Lamination',
              'specification': 'CRGO',
              'unit': 'kg',
              'quantity': 100,
              'rate': 250,
              'cost': 25000,
            }),
          ],
        ],
      );
      final controller = FilesController(
        routeId: 'entity-22',
        lomRepository: lomRepository,
        lomMaterialRepository: _FakeLomMaterialRepository(),
        designRepository: _FakeFilesDesignRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-22',
          designId: '100k-22345',
          twoWindings:
              '{"designId":"100k-22345","vectorGroup":"Dyn11","isOLTC":false,"isCSP":false,"core":{"coreWeight":100},"hvFormulas":{"hvProcurementWeight":45},"lvFormulas":{"lvProcurementWeight":55},"tankAndOilFormulas":{"hvConnectionWeight":12,"lvConnectionWeight":14,"insulationWeight":18,"totalOil":320,"weightOfTankAndAcc":900,"totalRadiatorWeight":410,"channelWeight":22}}',
          fabrication:
              '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true,"fill_Vlv_Nos":1},"smpl_Vlv":{"smpl_Vlv":false,"smpl_Vlv_Nos":0},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
        ),
      );

      final updated = await controller.updateRate(rowIndex: 0, rate: '250');

      expect(updated, isTrue);
      expect(lomRepository.requests, hasLength(2));
      expect(
        lomRepository.requests.last.toJson()['lomRate'],
        containsPair('lamination', 250),
      );
      expect(controller.state.rateOverrides, <String, num>{'lamination': 250});
      expect(controller.state.displayRows.single.rate, 250);
      expect(controller.state.totalCost, 25000);
    },
  );

  test(
    'custom rows are managed locally and saveDesign persists the raw lom items',
    () async {
      final designRepository = _FakeFilesDesignRepository();
      final controller = FilesController(
        routeId: 'entity-23',
        lomRepository: _FakeFilesLomRepository(
          response: <LomLineItem>[
            LomLineItem.fromJson(<String, dynamic>{
              'description': 'Lamination',
              'specification': 'CRGO',
              'unit': 'kg',
              'quantity': 100,
              'rate': 220,
              'cost': 22000,
            }),
          ],
        ),
        lomMaterialRepository: _FakeLomMaterialRepository(),
        designRepository: designRepository,
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: 'entity-23',
          designId: '100k-32345',
          twoWindings:
              '{"designId":"100k-32345","vectorGroup":"Dyn11","isOLTC":false,"isCSP":false,"core":{"coreWeight":100},"hvFormulas":{"hvProcurementWeight":45},"lvFormulas":{"lvProcurementWeight":55},"tankAndOilFormulas":{"hvConnectionWeight":12,"lvConnectionWeight":14,"insulationWeight":18,"totalOil":320,"weightOfTankAndAcc":900,"totalRadiatorWeight":410,"channelWeight":22}}',
          fabrication:
              '{"hvcb":{"hvcb":false},"lvcb":{"lvcb":true},"drain_Vlv":{"drain_Vlv":true,"drain_Vlv_Nos":2},"fill_Vlv":{"fill_Vlv":true,"fill_Vlv_Nos":1},"smpl_Vlv":{"smpl_Vlv":false,"smpl_Vlv_Nos":0},"mog":{"mog":true},"roller":{"roller":true},"cons":{"cons_Olg_Nos":1},"restOfVariables":{"prv":true}}',
        ),
      );

      controller.addCustomItem(
        description: 'Other Materials',
        specification: 'Custom',
        unit: 'lot',
        quantity: '2',
        rate: '900',
      );

      final updatedCustomRate = await controller.updateRate(
        rowIndex: 1,
        rate: 950,
      );
      final saved = await controller.saveDesign();

      expect(updatedCustomRate, isTrue);
      expect(saved, isTrue);
      expect(controller.state.displayRows, hasLength(2));
      expect(controller.state.displayRows.last.boolAt('isNew'), isTrue);
      expect(controller.state.displayRows.last.rate, 950);
      expect(controller.state.displayRows.last.cost, 1900);
      expect(designRepository.persistedEntityIds, <String>['entity-23']);
      expect(designRepository.persistedItems.single, hasLength(2));
      expect(
        designRepository.persistedItems.single.last.toJson(),
        <String, dynamic>{
          'description': 'Other Materials',
          'specification': 'Custom',
          'unit': 'lot',
          'quantity': 2,
          'rate': 950,
          'cost': 1900,
          'index': 1,
          'isNew': true,
          'rateKey': null,
        },
      );
    },
  );

  test(
    'missing design context blocks lom generation with a user-facing error',
    () async {
      final controller = FilesController(
        routeId: 'new',
        lomRepository: _FakeFilesLomRepository(),
        lomMaterialRepository: _FakeLomMaterialRepository(),
        designRepository: _FakeFilesDesignRepository(),
      );

      await controller.initialize(
        initialSummary: const DesignSummary(
          id: '',
          designId: '100k-42345',
          twoWindings: '{"designId":"100k-42345"}',
        ),
      );

      final refreshed = await controller.refreshLom();
      final saved = await controller.saveDesign();

      expect(refreshed, isFalse);
      expect(saved, isFalse);
      expect(
        controller.state.errorMessage,
        'Save the design before storing LOM changes.',
      );
    },
  );

  test('material fetch failures surface the backend message', () async {
    final controller = FilesController(
      routeId: 'entity-25',
      lomRepository: _FakeFilesLomRepository(),
      lomMaterialRepository: _FailingLomMaterialRepository(),
      designRepository: _FakeFilesDesignRepository(),
    );

    await controller.initialize(
      initialSummary: const DesignSummary(
        id: 'entity-25',
        designId: '100k-52345',
        twoWindings: '{"designId":"100k-52345"}',
        fabrication: '{"restOfVariables":{"prv":true}}',
      ),
    );

    expect(controller.state.materials, isEmpty);
    expect(controller.state.errorMessage, 'Material inventory unavailable.');
  });
}

class _FakeFilesLomRepository implements FilesLomRepository {
  _FakeFilesLomRepository({
    List<LomLineItem>? response,
    List<List<LomLineItem>>? responseSequence,
  }) : _response = response ?? const <LomLineItem>[],
       _responseSequence = responseSequence;

  final List<LomLineItem> _response;
  final List<List<LomLineItem>>? _responseSequence;
  final List<LomRequest> requests = <LomRequest>[];

  @override
  Future<List<LomLineItem>> generateLom(LomRequest request) async {
    requests.add(request);
    if (_responseSequence != null &&
        requests.length <= _responseSequence.length) {
      return _responseSequence[requests.length - 1];
    }
    return _response;
  }
}

class _FakeLomMaterialRepository implements LomMaterialRepository {
  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) async {
    return LomMaterialListResponse(
      data: List<LomMaterialEntry>.generate(39, (index) {
        final label = switch (index) {
          0 => 'Lamination',
          1 => 'HV Conductor',
          _ => 'Material $index',
        };
        final rate = switch (index) {
          0 => 220.0,
          1 => 125.0,
          _ => index.toDouble(),
        };
        return LomMaterialEntry.fromJson(<String, dynamic>{
          'id': 'material-$index',
          'materialName': label,
          'materialRate': rate,
        });
      }),
      total: 39,
    );
  }
}

class _FailingLomMaterialRepository implements LomMaterialRepository {
  @override
  Future<LomMaterialListResponse> fetchMaterials(EntityListQuery query) {
    throw const ApiException(
      type: ApiExceptionType.server,
      message: 'Material inventory unavailable.',
      statusCode: 503,
    );
  }
}

class _FakeFilesDesignRepository implements FilesDesignRepository {
  final List<String> persistedEntityIds = <String>[];
  final List<List<LomLineItem>> persistedItems = <List<LomLineItem>>[];

  @override
  Future<void> persistLom({
    required String entityId,
    required List<LomLineItem> items,
  }) async {
    persistedEntityIds.add(entityId);
    persistedItems.add(List<LomLineItem>.from(items));
  }
}
