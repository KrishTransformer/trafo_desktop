import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/models/entity_list_query.dart';
import '../../../core/network/api_exception.dart';
import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../fabrication/domain/models/fabrication_calculation_result.dart';
import '../../home/domain/models/design_summary.dart';
import '../../multi_winding/domain/models/multi_winding_design.dart';
import '../domain/models/lom_line_item.dart';
import '../domain/models/lom_request.dart';
import '../domain/repositories/files_design_repository.dart';
import '../domain/repositories/files_lom_repository.dart';
import '../domain/repositories/lom_material_repository.dart';
import 'files_state.dart';

class FilesController extends ChangeNotifier {
  FilesController({
    required String routeId,
    required FilesLomRepository lomRepository,
    required LomMaterialRepository lomMaterialRepository,
    required FilesDesignRepository designRepository,
  }) : _routeId = routeId,
       _lomRepository = lomRepository,
       _lomMaterialRepository = lomMaterialRepository,
       _designRepository = designRepository,
       _state = FilesState.initial(routeId: routeId);

  final String _routeId;
  final FilesLomRepository _lomRepository;
  final LomMaterialRepository _lomMaterialRepository;
  final FilesDesignRepository _designRepository;

  FilesState _state;

  FilesState get state => _state;

  Future<void> initialize({DesignSummary? initialSummary}) async {
    if (_state.isInitialized) {
      return;
    }

    final twoWindingDesign = _readFilesDesign(initialSummary);
    final fabricationResult = _readFabrication(initialSummary?.fabrication);
    final coreResult = _readCoreResult(initialSummary?.core);

    _setState(
      _state.copyWith(
        isInitialized: true,
        entityId: initialSummary?.id ?? (_routeId == 'new' ? '' : _routeId),
        designId:
            initialSummary?.designId ??
            twoWindingDesign?.stringAt('designId') ??
            '',
        twoWindingDesign: twoWindingDesign,
        fabricationResult: fabricationResult,
        coreResult: coreResult,
        errorMessage: '',
      ),
    );

    await _loadMaterialsAndGenerateLom();
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }
    _setState(_state.copyWith(errorMessage: ''));
  }

  void toggleAccordion(String sectionKey) {
    switch (sectionKey) {
      case 'LOM':
        _setState(_state.copyWith(isLomExpanded: !_state.isLomExpanded));
        break;
      case 'CCC':
        _setState(_state.copyWith(isCccExpanded: !_state.isCccExpanded));
        break;
    }
  }

  void setCustomerEditing(bool value) {
    if (_state.isCustomerEditing == value) {
      return;
    }
    _setState(_state.copyWith(isCustomerEditing: value));
  }

  void updateCustomerName(String value) {
    _setState(_state.copyWith(customerName: value, errorMessage: ''));
  }

  void updateCustomerPlace(String value) {
    _setState(_state.copyWith(customerPlace: value, errorMessage: ''));
  }

  Future<bool> refreshLom() async {
    if (_state.isLoading) {
      return false;
    }
    if (!_state.hasGenerationContext) {
      _setState(
        _state.copyWith(
          errorMessage:
              'Open files from a saved design with fabrication data before generating the LOM.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isLoading: true, errorMessage: ''));

    try {
      final request = _buildLomRequest();
      final response = await _lomRepository.generateLom(request);
      _setState(
        _state.copyWith(
          isLoading: false,
          lomItems: response,
          generatedRateKeys: request.lomRate.keys.toList(growable: false),
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isLoading: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to generate the LOM.',
        ),
      );
      return false;
    }
  }

  void addCustomItem({
    required String description,
    required String specification,
    required String unit,
    required Object? quantity,
    required Object? rate,
  }) {
    final normalizedDescription = description.trim();
    final normalizedSpecification = specification.trim();
    final normalizedUnit = unit.trim();
    final normalizedQuantity = _toNumber(quantity);
    final normalizedRate = _toNumber(rate);

    if (normalizedDescription.isEmpty ||
        normalizedSpecification.isEmpty ||
        normalizedUnit.isEmpty ||
        normalizedQuantity == null ||
        normalizedRate == null) {
      _setState(
        _state.copyWith(
          errorMessage: 'Fill all row fields before adding a LOM item.',
        ),
      );
      return;
    }

    final nextItems = List<LomLineItem>.from(_state.lomItems)
      ..add(
        LomLineItem.fromJson(<String, dynamic>{
          'description': normalizedDescription,
          'specification': normalizedSpecification,
          'unit': normalizedUnit,
          'quantity': normalizedQuantity,
          'rate': normalizedRate,
          'cost': normalizedQuantity * normalizedRate,
          'index': _state.lomItems.length,
          'isNew': true,
          'rateKey': null,
        }),
      );

    _setState(_state.copyWith(lomItems: nextItems, errorMessage: ''));
  }

  void deleteRow(int index) {
    if (index < 0 || index >= _state.lomItems.length) {
      return;
    }

    final nextItems = List<LomLineItem>.from(_state.lomItems)..removeAt(index);
    _setState(_state.copyWith(lomItems: nextItems, errorMessage: ''));
  }

  Future<bool> updateRate({
    required int rowIndex,
    required Object? rate,
  }) async {
    final normalizedRate = _toNumber(rate);
    if (normalizedRate == null ||
        rowIndex < 0 ||
        rowIndex >= _state.displayRows.length) {
      return false;
    }

    final row = _state.displayRows[rowIndex];
    if (row.boolAt('isNew')) {
      final nextItems = List<LomLineItem>.from(_state.lomItems);
      nextItems[rowIndex] = LomLineItem.fromJson(<String, dynamic>{
        ..._state.lomItems[rowIndex].toJson(),
        'rate': normalizedRate,
        'cost': row.numberAt('quantity') * normalizedRate,
      });
      _setState(_state.copyWith(lomItems: nextItems, errorMessage: ''));
      return true;
    }

    final rateKey = row.stringAt('rateKey').trim().isNotEmpty
        ? row.stringAt('rateKey')
        : _state.rateKeyForRow(rowIndex);
    if (rateKey == null || rateKey.isEmpty) {
      return false;
    }

    _setState(
      _state.copyWith(
        rateOverrides: <String, num>{
          ..._state.rateOverrides,
          rateKey: normalizedRate,
        },
        errorMessage: '',
      ),
    );
    return refreshLom();
  }

  Future<bool> saveDesign() async {
    if (_state.isSavingDesign) {
      return false;
    }
    if (!_state.hasSaveContext) {
      _setState(
        _state.copyWith(
          errorMessage: 'Save the design before storing LOM changes.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isSavingDesign: true, errorMessage: ''));

    try {
      await _designRepository.persistLom(
        entityId: _state.entityId,
        items: _state.lomItems,
      );
      _setState(_state.copyWith(isSavingDesign: false));
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isSavingDesign: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isSavingDesign: false,
          errorMessage: 'Unable to save the LOM for this design.',
        ),
      );
      return false;
    }
  }

  Future<void> _loadMaterialsAndGenerateLom() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: ''));

    try {
      final materialsResponse = await _lomMaterialRepository.fetchMaterials(
        const EntityListQuery(
          offset: 0,
          size: 100,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );
      _setState(
        _state.copyWith(isLoading: false, materials: materialsResponse.data),
      );
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isLoading: false, errorMessage: exception.message),
      );
      return;
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load the LOM material list.',
        ),
      );
      return;
    }

    final generated = await refreshLom();
    if (!generated && _state.errorMessage.isEmpty) {
      _setState(_state.copyWith(isLoading: false));
    }
  }

  LomRequest _buildLomRequest() {
    final twoWinding = _state.twoWindingDesign!;
    final fabrication = _state.fabricationResult!;

    final hvcbValue = fabrication.readPath('hvcb.hvcb');
    final lvcbValue = fabrication.readPath('lvcb.lvcb');
    final isOltcValue = twoWinding.readPath('isOLTC');
    final isCspValue = twoWinding.readPath('isCSP');

    final lomBooleans = <String, Object?>{
      'hvCableBox': hvcbValue == false ? false : true,
      'lvCableBox': lvcbValue == false ? false : true,
      'hvBushing': hvcbValue == false ? true : false,
      'lvBushing': lvcbValue == false ? true : false,
      'permaWood': true,
      'drainValve': fabrication.readPath('drain_Vlv.drain_Vlv'),
      'filterValve': fabrication.readPath('fill_Vlv.fill_Vlv'),
      'samplingValve': fabrication.readPath('smpl_Vlv.smpl_Vlv'),
      'relayShutOffValve': true,
      'thermometerPocket': true,
      'airReleasePlug': true,
      'oltc': isOltcValue,
      'octc': isOltcValue == true ? false : true,
      'oti': true,
      'wti': true,
      'buchholzRelay': true,
      'marshallingBox': true,
      'oilLevelGauge': isCspValue == false ? true : false,
      'mog': fabrication.readPath('mog.mog'),
      'pressureReliefValve': fabrication.readPath('restOfVariables.prv'),
      'oilCirculatingPump': true,
      'avrrtcc': true,
      'rollers': fabrication.readPath('roller.roller'),
      'pumpControlCubicle': true,
      'biMetallicConnector': true,
      'fasteners': true,
    };

    final vectorGroup = twoWinding.stringAt('vectorGroup');
    final hvVector = vectorGroup.isNotEmpty ? vectorGroup[0] : '';
    final lvVector = vectorGroup.length > 1 ? vectorGroup[1] : '';

    final lomQuantity = <String, Object?>{
      'lamination': twoWinding.readPath('core.coreWeight'),
      'hvConductor': twoWinding.readPath('hvFormulas.hvProcurementWeight'),
      'lvConductor': twoWinding.readPath('lvFormulas.lvProcurementWeight'),
      'hvConnectionLeads': twoWinding.readPath(
        'tankAndOilFormulas.hvConnectionWeight',
      ),
      'lvConnectionLeads': twoWinding.readPath(
        'tankAndOilFormulas.lvConnectionWeight',
      ),
      'insulationMaterial': twoWinding.readPath(
        'tankAndOilFormulas.insulationWeight',
      ),
      'transformerOil': twoWinding.readPath('tankAndOilFormulas.totalOil'),
      'tankLidEtc': twoWinding.readPath(
        'tankAndOilFormulas.weightOfTankAndAcc',
      ),
      'hvCableBox': 1,
      'lvCableBox': 1,
      'hvBushing': hvVector == 'D' ? 3 : 4,
      'lvBushing': lvVector == 'd' ? 3 : 4,
      'radiatorsAndHeatExc': twoWinding.readPath(
        'tankAndOilFormulas.totalRadiatorWeight',
      ),
      'permaWood': 0.0,
      'drainValve': fabrication.readPath('drain_Vlv.drain_Vlv_Nos'),
      'filterValve': fabrication.readPath('fill_Vlv.fill_Vlv_Nos'),
      'samplingValve': fabrication.readPath('smpl_Vlv.smpl_Vlv_Nos'),
      'relayShutOffValve': 0.0,
      'breatherSilicaGel': 1,
      'ratingPlate': 1,
      'thermometerPocket': 1,
      'airReleasePlug': 0.0,
      'coreBoltsAndTieRods': twoWinding.readPath(
        'tankAndOilFormulas.channelWeight',
      ),
      'oltc': 1,
      'octc': 1,
      'oti': 0.0,
      'wti': 0.0,
      'buchholzRelay': 0.0,
      'marshallingBox': 0.0,
      'oilLevelGauge': fabrication.readPath('cons.cons_Olg_Nos'),
      'mog': 1,
      'pressureReliefValve': 0.0,
      'oilCirculatingPump': 0.0,
      'avrrtcc': 0.0,
      'rollers': 4,
      'pumpControlCubicle': 0.0,
      'biMetallicConnector': 0.0,
      'fasteners': 0.0,
      'otherMaterials': 0.0,
    };

    final rateOverrides = _state.rateOverrides;
    final lomRate = <String, Object?>{
      'lamination': rateOverrides['lamination'] ?? _materialRateAt(0),
      'hvConductor': rateOverrides['hvConductor'] ?? _materialRateAt(1),
      'lvConductor': rateOverrides['lvConductor'] ?? _materialRateAt(2),
      'hvConnectionLeads':
          rateOverrides['hvConnectionLeads'] ?? _materialRateAt(3),
      'lvConnectionLeads':
          rateOverrides['lvConnectionLeads'] ?? _materialRateAt(4),
      'insulationMaterial':
          rateOverrides['insulationMaterial'] ?? _materialRateAt(5),
      'transformerOil': rateOverrides['transformerOil'] ?? _materialRateAt(6),
      'tankLidEtc': rateOverrides['tankLidEtc'] ?? _materialRateAt(7),
      if (lomBooleans['hvCableBox'] == true)
        'hvCableBox': rateOverrides['hvCableBox'] ?? _materialRateAt(8),
      if (lomBooleans['lvCableBox'] == true)
        'lvCableBox': rateOverrides['lvCableBox'] ?? _materialRateAt(9),
      if (lomBooleans['hvBushing'] == true)
        'hvBushing': rateOverrides['hvBushing'] ?? _materialRateAt(10),
      if (lomBooleans['lvBushing'] == true)
        'lvBushing': rateOverrides['lvBushing'] ?? _materialRateAt(11),
      'radiatorsAndHeatExc':
          rateOverrides['radiatorsAndHeatExc'] ?? _materialRateAt(12),
      'permaWood': rateOverrides['permaWood'] ?? _materialRateAt(13),
      if (_isTruthy(lomBooleans['drainValve']))
        'drainValve': rateOverrides['drainValve'] ?? _materialRateAt(14),
      if (_isTruthy(lomBooleans['filterValve']))
        'filterValve': rateOverrides['filterValve'] ?? _materialRateAt(15),
      if (_isTruthy(lomBooleans['samplingValve']))
        'samplingValve': rateOverrides['samplingValve'] ?? _materialRateAt(16),
      'relayShutOffValve':
          rateOverrides['relayShutOffValve'] ?? _materialRateAt(17),
      'breatherSilicaGel':
          rateOverrides['breatherSilicaGel'] ?? _materialRateAt(18),
      'ratingPlate': rateOverrides['ratingPlate'] ?? _materialRateAt(19),
      'thermometerPocket':
          rateOverrides['thermometerPocket'] ?? _materialRateAt(20),
      'airReleasePlug': rateOverrides['airReleasePlug'] ?? _materialRateAt(21),
      'coreBoltsAndTieRods':
          rateOverrides['coreBoltsAndTieRods'] ?? _materialRateAt(22),
      if (_isTruthy(lomBooleans['oltc']))
        'oltc': rateOverrides['oltc'] ?? _materialRateAt(23),
      if (_isTruthy(lomBooleans['octc']))
        'octc': rateOverrides['octc'] ?? _materialRateAt(24),
      'oti': rateOverrides['oti'] ?? _materialRateAt(25),
      'wti': rateOverrides['wti'] ?? _materialRateAt(26),
      'buchholzRelay': rateOverrides['buchholzRelay'] ?? _materialRateAt(27),
      'marshallingBox': rateOverrides['marshallingBox'] ?? _materialRateAt(28),
      if (_isTruthy(lomBooleans['oilLevelGauge']))
        'oilLevelGauge': rateOverrides['oilLevelGauge'] ?? _materialRateAt(29),
      if (_isTruthy(lomBooleans['mog']))
        'mog': rateOverrides['mog'] ?? _materialRateAt(30),
      if (_isTruthy(lomBooleans['pressureReliefValve']))
        'pressureReliefValve':
            rateOverrides['pressureReliefValve'] ?? _materialRateAt(31),
      'oilCirculatingPump':
          rateOverrides['oilCirculatingPump'] ?? _materialRateAt(32),
      'avrrtcc': rateOverrides['avrrtcc'] ?? _materialRateAt(33),
      if (_isTruthy(lomBooleans['rollers']))
        'rollers': rateOverrides['rollers'] ?? _materialRateAt(34),
      'pumpControlCubicle':
          rateOverrides['pumpControlCubicle'] ?? _materialRateAt(35),
      'biMetallicConnector':
          rateOverrides['biMetallicConnector'] ?? _materialRateAt(36),
      'fasteners': rateOverrides['fasteners'] ?? _materialRateAt(37),
      'otherMaterials': rateOverrides['otherMaterials'] ?? _materialRateAt(38),
    };

    return LomRequest(
      lomBooleans: lomBooleans,
      lomQuantity: lomQuantity,
      lomRate: lomRate,
    );
  }

  num _materialRateAt(int index) {
    if (index < 0 || index >= _state.materials.length) {
      return 0.0;
    }
    return _state.materials[index].materialRate;
  }

  bool _isTruthy(Object? value) {
    return switch (value) {
      true => true,
      false => false,
      null => false,
      String() => value.trim().isNotEmpty && value.toLowerCase() != 'false',
      num() => value != 0,
      _ => true,
    };
  }

  num? _toNumber(Object? value) {
    return switch (value) {
      num() => value,
      String() => num.tryParse(value.trim()),
      _ => null,
    };
  }

  TwoWindingDesign? _readTwoWindingDesign(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : TwoWindingDesign.fromJson(json);
  }

  TwoWindingDesign? _readFilesDesign(DesignSummary? summary) {
    final twoWindingDesign = _readTwoWindingDesign(summary?.twoWindings);
    if (twoWindingDesign != null) {
      return twoWindingDesign;
    }

    final multiJson = _readJsonMap(summary?.multiWindings);
    if (multiJson == null) {
      return null;
    }

    final adapted = MultiWindingDesign.fromJson(multiJson).toJson();
    final windings = _map(adapted['part2Windings']);
    final lv = _map(windings['lv']);
    final hv = _map(windings['hvMain']);
    final conductors = _map(_map(adapted['multiCost'])['conductors']);
    final lvCost = _map(conductors['lv']);
    final hvCost = _map(conductors['hvMain']);
    final performance = _map(adapted['performance']);

    adapted['designId'] = summary?.designId ?? adapted['designId'];
    adapted['innerWindings'] = lv;
    adapted['outerWindings'] = hv;
    adapted['lvFormulas'] = <String, dynamic>{
      'lvCurrentPerPhase': lv['phaseCurrent'],
      'lvProcurementWeight': lvCost['weight'],
    };
    adapted['hvFormulas'] = <String, dynamic>{
      'hvCurrentPerPhase': hv['phaseCurrent'],
      'hvProcurementWeight': hvCost['weight'],
    };
    adapted['commonFormulas'] = <String, dynamic>{
      'ek': performance['impedance'] ?? adapted['ez'],
    };

    return TwoWindingDesign.fromJson(adapted);
  }

  CoreCalculationResult? _readCoreResult(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : CoreCalculationResult.fromJson(json);
  }

  FabricationCalculationResult? _readFabrication(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : FabricationCalculationResult.fromJson(json);
  }

  Map<String, dynamic>? _readJsonMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<Object?, Object?>) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  void _setState(FilesState value) {
    if (_state == value) {
      return;
    }
    _state = value;
    notifyListeners();
  }
}
