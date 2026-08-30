import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../home/domain/models/design_summary.dart';
import '../domain/models/multi_winding_design.dart';
import '../domain/repositories/multi_winding_repositories.dart';

class MultiWindingState {
  const MultiWindingState({
    required this.design,
    required this.isLoading,
    required this.isCalculating,
    required this.errorMessage,
    required this.designId,
  });

  factory MultiWindingState.initial() => MultiWindingState(
    design: MultiWindingDesign.initial(),
    isLoading: false,
    isCalculating: false,
    errorMessage: '',
    designId: '',
  );

  final MultiWindingDesign design;
  final bool isLoading;
  final bool isCalculating;
  final String errorMessage;
  final String designId;

  MultiWindingState copyWith({
    MultiWindingDesign? design,
    bool? isLoading,
    bool? isCalculating,
    String? errorMessage,
    String? designId,
  }) => MultiWindingState(
    design: design ?? this.design,
    isLoading: isLoading ?? this.isLoading,
    isCalculating: isCalculating ?? this.isCalculating,
    errorMessage: errorMessage ?? this.errorMessage,
    designId: designId ?? this.designId,
  );
}

class MultiWindingController extends ChangeNotifier {
  MultiWindingController({
    required MultiWindingCalculationRepository calculationRepository,
    required MultiWindingDesignRepository designRepository,
  }) : _calculationRepository = calculationRepository,
       _designRepository = designRepository;

  static const Map<String, List<String>>
  _windingsByConfiguration = <String, List<String>>{
    '2_WDG_LV_HV_MAIN': <String>['lv', 'hvMain'],
    '3_WDG_LV_HV_MAIN_OUTER': <String>['lv', 'hvMain', 'outer'],
    '4_WDG_LV_HV_MAIN_CORSE_OUTER': <String>['lv', 'hvMain', 'corse', 'outer'],
    '4_WDG_LV_HV_MAIN_FINE_OUTER': <String>['lv', 'hvMain', 'fine', 'outer'],
    '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER': <String>[
      'lv',
      'hvMain',
      'corse',
      'fine',
      'outer',
    ],
  };
  static const Map<String, String> _lockGroupByWinding = <String, String>{
    'lv': 'lvWindings',
    'hvMain': 'hvWindings',
    'corse': 'corseWindings',
    'fine': 'fineWindings',
    'outer': 'outerWindings',
  };

  final MultiWindingCalculationRepository _calculationRepository;
  final MultiWindingDesignRepository _designRepository;
  MultiWindingState _state = MultiWindingState.initial();
  MultiWindingState get state => _state;

  List<String> get activeWindings =>
      _windingsByConfiguration[state.design.textAt('windingConfiguration')] ??
      _windingsByConfiguration['2_WDG_LV_HV_MAIN']!;

  void initialize({DesignSummary? initialSummary}) {
    if (initialSummary == null || initialSummary.multiWindings == null) return;
    final decoded = _decodeDesign(initialSummary.multiWindings);
    if (decoded.isEmpty) return;
    _setState(
      _state.copyWith(
        design: MultiWindingDesign.fromJson(decoded),
        designId: initialSummary.designId,
      ),
    );
  }

  void update(String path, Object? value) {
    var next = state.design.copyWithPath(path, value);
    if (path == 'kVA') {
      next = _clearInactiveLocks(_applyKvaDefaults(next, value));
    }
    if (path == 'windingConfiguration') next = _clearInactiveLocks(next);
    final densityPath = <String, String>{
      'lVConductorMaterial': 'lvCurrentDensity',
      'hVConductorMaterial': 'hvCurrentDensity',
      'corseConductorMaterial': 'corseCurrentDensity',
      'fineConductorMaterial': 'fineCurrentDensity',
      'outerConductorMaterial': 'outerCurrentDensity',
    }[path];
    if (densityPath != null) {
      next = next.copyWithPath(densityPath, value == 'Al' ? '2.37' : '3.63');
    }
    _setState(_state.copyWith(design: next, errorMessage: ''));
  }

  void toggleCoreLock(String field) => _toggleLock('coreLock', field);

  void toggleWindingLock(String windingId, String field) =>
      _toggleLock(_lockGroupByWinding[windingId]!, field);

  void reset() => _setState(MultiWindingState.initial());

  Future<bool> calculate() async {
    if (state.isCalculating) return false;
    _setState(_state.copyWith(isCalculating: true, errorMessage: ''));
    try {
      final request = buildPayload(state.design);
      final response = await _calculationRepository.calculate(request);
      final generatedId = _generateDesignId(response, request);
      final calculated = _mergeResponse(
        response,
        state.design,
        request,
      ).copyWithPath('designId', generatedId);
      final entityId = await _designRepository.createDesign(
        designId: generatedId,
        design: calculated,
      );
      _setState(
        _state.copyWith(
          isCalculating: false,
          design: calculated,
          designId: entityId.isEmpty ? generatedId : generatedId,
        ),
      );
      return true;
    } catch (_) {
      _setState(
        _state.copyWith(
          isCalculating: false,
          errorMessage: 'Unable to calculate the multi-winding design.',
        ),
      );
      return false;
    }
  }

  Map<String, dynamic> buildPayload(MultiWindingDesign design) {
    final source = design.toJson();
    final configuration = _text(source['windingConfiguration']);
    final active =
        _windingsByConfiguration[configuration] ??
        _windingsByConfiguration['2_WDG_LV_HV_MAIN']!;
    final locks = _normalizeLocks(_map(source['lockedAttributes']));
    final windingData = _map(source['part2Windings']);
    final payload = <String, dynamic>{
      'designId': _nullable(source['designId']),
      'windingSelection': _selectionFor(configuration),
      'kVA': _integer(source['kVA']),
      'kValue': 0.45,
      'fluxDensity': _number(source['fluxDensity']),
      'vectorGroup': _nullable(source['vectorGroup']),
      'lowVoltage': _integer(source['primaryVoltage'] ?? source['lowVoltage']),
      'highVoltage': _integer(
        source['secondaryVoltage'] ?? source['highVoltage'],
      ),
      'tapStepsPercentage': _number(source['tapStepsPercent']),
      'tapStepPositive': _integer(source['tapStepsPositive']),
      'tapStepNegative': _integer(source['tapStepsNegative']),
      'core': <String, dynamic>{
        'coreDia': _isLocked(locks, 'coreLock', 'coreDia')
            ? _integer(_map(source['core'])['coreDia'])
            : null,
        'limbHt': _isLocked(locks, 'coreLock', 'limbHt')
            ? _integer(_map(source['core'])['limbHt'])
            : null,
      },
      'lockedAttributes': locks,
      'cost': _map(source['cost']),
      'radialGaps': _buildRadialGaps(source, configuration),
    };
    for (final windingId in active) {
      final apiKey = _lockGroupByWinding[windingId]!;
      final prefix = windingId == 'hvMain' ? 'hv' : windingId;
      payload['${prefix}WindingType'] = _nullable(
        source['${prefix}WindingType'],
      );
      payload['${prefix}CurrentDensity'] = _number(
        source['${prefix}CurrentDensity'],
      );
      payload[apiKey] = _buildWinding(
        _map(windingData[windingId]),
        _map(locks[apiKey]),
      );
    }
    return payload;
  }

  Map<String, dynamic> _buildRadialGaps(
    Map<String, dynamic> source,
    String configuration,
  ) {
    final coil = _map(source['coilDimensions']);
    final gaps = _map(_map(source['multiCoilDimensions'])['gaps']);
    final all = <String, Object?>{
      'coreToLv': coil['coreGap'],
      'lvToHv': coil['lvhvgap'],
      'hvToOuter': coil['hvhvgap'] ?? gaps['hvMainToOuterGap'],
      'hvToCorse': gaps['hvMainToCorseGap'],
      'corseToOuter': gaps['corseToOuterGap'],
      'hvToFine': gaps['hvMainToFineGap'],
      'fineToOuter': gaps['fineToOuterGap'],
      'corseToFine': gaps['corseToFineGap'],
    };
    final active = switch (configuration) {
      '3_WDG_LV_HV_MAIN_OUTER' => ['coreToLv', 'lvToHv', 'hvToOuter'],
      '4_WDG_LV_HV_MAIN_CORSE_OUTER' => [
        'coreToLv',
        'lvToHv',
        'hvToCorse',
        'corseToOuter',
      ],
      '4_WDG_LV_HV_MAIN_FINE_OUTER' => [
        'coreToLv',
        'lvToHv',
        'hvToFine',
        'fineToOuter',
      ],
      '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER' => [
        'coreToLv',
        'lvToHv',
        'hvToCorse',
        'corseToFine',
        'fineToOuter',
      ],
      _ => ['coreToLv', 'lvToHv'],
    };
    return <String, dynamic>{
      for (final key in active) key: _nullable(all[key]),
    };
  }

  Map<String, dynamic> _buildWinding(
    Map<String, dynamic> winding,
    Map<String, dynamic> locks,
  ) => <String, dynamic>{
    'turnsPerPhase': _isLocked(locks, '', 'turnsPerPhase')
        ? _number(winding['turnsPerPhase'])
        : null,
    'condBreadth': _isLocked(locks, '', 'conductorSizes')
        ? _number(winding['condBreadth'])
        : null,
    'condHeight': _isLocked(locks, '', 'conductorSizes')
        ? _number(winding['condHeight'])
        : null,
    'conductorDiameter': _isLocked(locks, '', 'conductorSizes')
        ? _number(winding['conductorDiameter'])
        : null,
    'conductorSizes': _isLocked(locks, '', 'conductorSizes')
        ? _formatConductorSizes(winding)
        : '',
    'radialParallelCond': _isLocked(locks, '', 'noInParallel')
        ? _integer(winding['radialParallelCond'])
        : null,
    'axialParallelCond': _isLocked(locks, '', 'noInParallel')
        ? _integer(winding['axialParallelCond'])
        : null,
    'noInParallel': _isLocked(locks, '', 'noInParallel')
        ? _formatParallelCount(winding)
        : '',
    'noOfLayers': _integer(winding['noOfLayers']),
    'ducts': _integer(winding['ducts']),
    'ductSize': _integer(winding['ductSize']),
    'condInsulation': _number(winding['condInsulation']),
    'interLayerInsulation': _number(winding['interLayerInsulation']),
    'endClearances': _number(winding['endClearances']),
    'isConductorRound': _isLocked(locks, '', 'conductorSizes')
        ? winding['isConductorRound'] == true
        : null,
    'isEnamel': winding['isEnamel'] == true,
  };

  static String _formatConductorSizes(Map<String, dynamic> winding) {
    if (winding['isConductorRound'] == true) {
      final diameter = _text(winding['conductorDiameter']);
      return diameter.isEmpty ? '' : 'Round $diameter';
    }
    final breadth = _text(winding['condBreadth']);
    final height = _text(winding['condHeight']);
    return breadth.isEmpty || height.isEmpty ? '' : '$breadth L X $height B';
  }

  static String _formatParallelCount(Map<String, dynamic> winding) {
    final radial = _text(winding['radialParallelCond']);
    final axial = _text(winding['axialParallelCond']);
    if (radial.isEmpty && axial.isEmpty) return '';
    final total = (_number(radial) ?? 0) * (_number(axial) ?? 0);
    return 'Rad $radial X Axi $axial = $total';
  }

  void _toggleLock(String group, String field) {
    final locks = _normalizeLocks(
      _map(state.design.readPath('lockedAttributes')),
    );
    final values = _map(locks[group]);
    final next = values[field] != true;
    values[field] = next;
    if (field == 'conductorSizes') {
      values['condBreadth'] = next;
      values['condHeight'] = next;
      if (next) values['noInParallel'] = false;
    }
    if (field == 'noInParallel' && next) {
      values['conductorSizes'] = false;
      values['condBreadth'] = false;
      values['condHeight'] = false;
    }
    locks[group] = values;
    _setState(
      _state.copyWith(
        design: state.design.copyWithPath('lockedAttributes', locks),
      ),
    );
  }

  MultiWindingDesign _clearInactiveLocks(MultiWindingDesign design) {
    final locks = _normalizeLocks(_map(design.readPath('lockedAttributes')));
    final active =
        _windingsByConfiguration[design.textAt('windingConfiguration')] ??
        _windingsByConfiguration['2_WDG_LV_HV_MAIN']!;
    for (final entry in _lockGroupByWinding.entries) {
      if (!active.contains(entry.key)) {
        locks[entry.value] = <String, dynamic>{
          'turnsPerPhase': false,
          'conductorSizes': false,
          'noInParallel': false,
          'condBreadth': false,
          'condHeight': false,
        };
      }
    }
    return design.copyWithPath('lockedAttributes', locks);
  }

  MultiWindingDesign _applyKvaDefaults(
    MultiWindingDesign design,
    Object? value,
  ) {
    final kva = _number(value) ?? 0;
    final defaults = kva <= 2500
        ? <String, Object>{
            'windingConfiguration': '2_WDG_LV_HV_MAIN',
            'primaryVoltage': 433,
            'secondaryVoltage': 11000,
            'lvWindingType': 'HELICAL',
            'hvWindingType': 'HELICAL',
          }
        : kva <= 10000
        ? <String, Object>{
            'windingConfiguration': '3_WDG_LV_HV_MAIN_OUTER',
            'primaryVoltage': 11000,
            'secondaryVoltage': 33000,
            'lvWindingType': 'DISC',
            'hvWindingType': 'DISC',
          }
        : kva <= 20000
        ? <String, Object>{
            'windingConfiguration': '4_WDG_LV_HV_MAIN_CORSE_OUTER',
            'primaryVoltage': 11000,
            'secondaryVoltage': 66000,
            'lvWindingType': 'DISC',
            'hvWindingType': 'DISC',
          }
        : <String, Object>{
            'windingConfiguration': '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER',
            'primaryVoltage': 33000,
            'secondaryVoltage': 132000,
            'lvWindingType': 'DISC',
            'hvWindingType': 'DISC',
          };
    var next = design;
    defaults.forEach(
      (key, defaultValue) => next = next.copyWithPath(key, defaultValue),
    );
    return next;
  }

  MultiWindingDesign _mergeResponse(
    Map<String, dynamic> response,
    MultiWindingDesign current,
    Map<String, dynamic> request,
  ) {
    final merged = current.toJson();
    final inputs = _map(response['inputs']);
    final results = _map(response['results']);
    final ratings = _map(inputs['ratings']);
    final dimensions = _map(results['coilDimensions']);
    final tankAndOil = _map(results['tankAndOil']);
    final inputWindings = _map(inputs['windingModels']);
    final calculatedCore = _map(results['core']);

    _putIfPresent(merged, 'kVA', ratings['kVA'] ?? response['kVA']);
    _putIfPresent(merged, 'primaryVoltage', ratings['lowVoltage']);
    _putIfPresent(merged, 'secondaryVoltage', ratings['highVoltage']);
    _putIfPresent(merged, 'fluxDensity', ratings['fluxDensity']);
    _putIfPresent(merged, 'vectorGroup', inputs['vectorGroup']);
    merged['core'] = <String, dynamic>{
      ..._map(merged['core']),
      ...calculatedCore,
      'coreWeight':
          calculatedCore['weight'] ??
          calculatedCore['coreWeight'] ??
          _map(merged['core'])['coreWeight'],
      'area': calculatedCore['area'] ?? _map(merged['core'])['area'],
    };
    merged['performance'] = <String, dynamic>{
      ..._map(merged['performance']),
      'noLoadLoss':
          results['noLoadLoss'] ??
          results['coreLoss'] ??
          _map(merged['performance'])['noLoadLoss'],
      'loadLoss':
          _map(results['hvWinding'])['totalLoadLoss'] ??
          _map(merged['performance'])['loadLoss'],
      'impedance':
          _map(results['impedance'])['ek'] ??
          _map(results['common'])['ek'] ??
          _map(merged['performance'])['impedance'],
      'nlCurrentPercentage':
          results['nlCurrentPercentage'] ??
          _map(merged['performance'])['nlCurrentPercentage'],
      'voltsPerTurn':
          results['revisedVoltsPerTurn'] ??
          results['voltsPerTurn'] ??
          _map(merged['performance'])['voltsPerTurn'],
    };
    merged['tankAndOilFormulas'] = <String, dynamic>{
      ..._map(merged['tankAndOilFormulas']),
      'totalSteelWeight':
          tankAndOil['totalSteelWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalSteelWeight'],
      'totalOil':
          tankAndOil['totalOil'] ??
          _map(merged['tankAndOilFormulas'])['totalOil'],
      'insulationWeight':
          tankAndOil['insulationWeight'] ??
          _map(merged['tankAndOilFormulas'])['insulationWeight'],
      'totalRadiatorWeight':
          tankAndOil['totalRadiatorWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalRadiatorWeight'],
      'transformerWeight':
          tankAndOil['transformerWeight'] ??
          _map(merged['tankAndOilFormulas'])['transformerWeight'],
    };
    merged['coilDimensions'] = <String, dynamic>{
      ..._map(merged['coilDimensions']),
      'coreDia':
          dimensions['coreDia'] ?? _map(merged['coilDimensions'])['coreDia'],
      'coreGap':
          dimensions['coreGap'] ?? _map(merged['coilDimensions'])['coreGap'],
      'lvid': dimensions['lVID'] ?? _map(merged['coilDimensions'])['lvid'],
      'lvradial':
          dimensions['lVRadial'] ?? _map(merged['coilDimensions'])['lvradial'],
      'lvod': dimensions['lVOD'] ?? _map(merged['coilDimensions'])['lvod'],
      'lvhvgap':
          dimensions['lVHVGap'] ?? _map(merged['coilDimensions'])['lvhvgap'],
      'hvid': dimensions['hVID'] ?? _map(merged['coilDimensions'])['hvid'],
      'hvradial':
          dimensions['hVRadial'] ?? _map(merged['coilDimensions'])['hvradial'],
      'hvod': dimensions['hVOD'] ?? _map(merged['coilDimensions'])['hvod'],
      'hvhvgap':
          dimensions['hVHVGap'] ?? _map(merged['coilDimensions'])['hvhvgap'],
    };
    merged['multiCoilDimensions'] = <String, dynamic>{
      ..._map(merged['multiCoilDimensions']),
      'corse': _coilDimension(dimensions, merged, 'corse'),
      'fine': _coilDimension(dimensions, merged, 'fine'),
      'outer': _coilDimension(dimensions, merged, 'outer'),
      'gaps': _responseGaps(dimensions, merged),
    };
    merged['cost'] = <String, dynamic>{
      ..._map(merged['cost']),
      'totalCondCost':
          tankAndOil['conductorCost'] ?? _map(merged['cost'])['totalCondCost'],
      'totalCoreCost':
          tankAndOil['coreCost'] ?? _map(merged['cost'])['totalCoreCost'],
      'totalSteelCost':
          tankAndOil['steelCost'] ?? _map(merged['cost'])['totalSteelCost'],
      'totalOilCost':
          tankAndOil['oilCost'] ?? _map(merged['cost'])['totalOilCost'],
      'totalInsCost':
          tankAndOil['insulationCost'] ?? _map(merged['cost'])['totalInsCost'],
      'totalRadiatorCost':
          tankAndOil['radiatorCost'] ??
          _map(merged['cost'])['totalRadiatorCost'],
      'capitalCost':
          tankAndOil['capitalCost'] ?? _map(merged['cost'])['capitalCost'],
    };
    final windingIds = <String, String>{
      'lv': 'lv',
      'hvMain': 'hv',
      'corse': 'corse',
      'fine': 'fine',
      'outer': 'outer',
    };
    final existingWindings = _map(merged['part2Windings']);
    for (final entry in windingIds.entries) {
      final result = _map(results['${entry.value}Winding']);
      existingWindings[entry.key] = <String, dynamic>{
        ..._map(existingWindings[entry.key]),
        ..._map(inputWindings[entry.value]),
        'turnsPerPhase':
            result['turnsPerPhase'] ??
            _map(existingWindings[entry.key])['turnsPerPhase'],
        'condBreadth':
            result['breadth'] ??
            _map(existingWindings[entry.key])['condBreadth'],
        'condHeight':
            result['height'] ?? _map(existingWindings[entry.key])['condHeight'],
        'conductorDiameter':
            result['conductorDiameter'] ??
            _map(existingWindings[entry.key])['conductorDiameter'],
        'radialParallelCond':
            result['radialParallelCond'] ??
            _map(existingWindings[entry.key])['radialParallelCond'],
        'axialParallelCond':
            result['axialParallelCond'] ??
            _map(existingWindings[entry.key])['axialParallelCond'],
        'condInsulation':
            result['conductorInsulation'] ??
            _map(existingWindings[entry.key])['condInsulation'],
        'interLayerInsulation':
            result['interLayerInsulation'] ??
            _map(existingWindings[entry.key])['interLayerInsulation'],
        'endClearances':
            result['endClearance'] ??
            _map(existingWindings[entry.key])['endClearances'],
        'noOfLayers':
            result['noOfLayers'] ??
            _map(existingWindings[entry.key])['noOfLayers'],
        'ducts': result['ducts'] ?? _map(existingWindings[entry.key])['ducts'],
        'ductSize':
            result['ductSize'] ?? _map(existingWindings[entry.key])['ductSize'],
      };
    }
    merged['part2Windings'] = existingWindings;
    final conductorCosts = _map(_map(merged['multiCost'])['conductors']);
    for (final entry in windingIds.entries) {
      final winding = _map(results['${entry.value}Winding']);
      final materialKey = <String, String>{
        'lv': 'lVConductorMaterial',
        'hvMain': 'hVConductorMaterial',
        'corse': 'corseConductorMaterial',
        'fine': 'fineConductorMaterial',
        'outer': 'outerConductorMaterial',
      }[entry.key]!;
      final material = _text(merged[materialKey]);
      final rate = material == 'Al'
          ? _number(_map(merged['cost'])['aluminiumCostPerKg'])
          : _number(_map(merged['cost'])['copperCostPerKg']);
      final weight =
          winding['insulatedWeight'] ??
          _map(inputWindings[entry.value])['insulatedWeight'];
      conductorCosts[entry.key] = <String, dynamic>{
        ..._map(conductorCosts[entry.key]),
        'weight': weight ?? _map(conductorCosts[entry.key])['weight'],
        'totalCost':
            _conductorCost(weight, rate) ??
            _map(conductorCosts[entry.key])['totalCost'],
      };
    }
    merged['multiCost'] = <String, dynamic>{
      ..._map(merged['multiCost']),
      'conductors': conductorCosts,
    };
    merged['lockedAttributes'] = _normalizeLocks(
      _map(request['lockedAttributes']),
    );
    merged['calculationResponse'] = response;
    return MultiWindingDesign.fromJson(merged);
  }

  static void _putIfPresent(
    Map<String, dynamic> target,
    String key,
    Object? value,
  ) {
    if (value != null) target[key] = value;
  }

  static double? _conductorCost(Object? weight, double? rate) {
    final parsedWeight = _number(weight);
    if (parsedWeight == null || rate == null) return null;
    return parsedWeight * rate;
  }

  static Map<String, dynamic> _coilDimension(
    Map<String, dynamic> dimensions,
    Map<String, dynamic> design,
    String id,
  ) {
    final existing = _map(_map(design['multiCoilDimensions'])[id]);
    final responseKey = id == 'corse' ? 'corse' : id;
    return <String, dynamic>{
      ...existing,
      'id': dimensions['${responseKey}ID'] ?? existing['id'],
      'radial': dimensions['${responseKey}Radial'] ?? existing['radial'],
      'od': dimensions['${responseKey}OD'] ?? existing['od'],
    };
  }

  static Map<String, dynamic> _responseGaps(
    Map<String, dynamic> dimensions,
    Map<String, dynamic> design,
  ) {
    final existing = _map(_map(design['multiCoilDimensions'])['gaps']);
    return <String, dynamic>{
      ...existing,
      'hvMainToOuterGap': dimensions['hVHVGap'] ?? existing['hvMainToOuterGap'],
      'hvMainToCorseGap':
          dimensions['corseGap'] ?? existing['hvMainToCorseGap'],
      'corseToOuterGap': dimensions['outerGap'] ?? existing['corseToOuterGap'],
      'hvMainToFineGap': dimensions['fineGap'] ?? existing['hvMainToFineGap'],
      'fineToOuterGap': dimensions['outerGap'] ?? existing['fineToOuterGap'],
      'corseToFineGap': dimensions['fineGap'] ?? existing['corseToFineGap'],
    };
  }

  String _generateDesignId(
    Map<String, dynamic> response,
    Map<String, dynamic> request,
  ) {
    final kva =
        _integer(
          response['kVA'] ?? _map(response['inputs'])['kVA'] ?? request['kVA'],
        ) ??
        0;
    return '${kva}k-M${10000 + Random().nextInt(90000)}';
  }

  static Map<String, dynamic> _decodeDesign(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static String _text(Object? value) => value?.toString() ?? '';
  static Object? _nullable(Object? value) =>
      _text(value).trim().isEmpty ? null : value;
  static int? _integer(Object? value) => int.tryParse(_text(value));
  static double? _number(Object? value) => double.tryParse(_text(value));
  static bool _isLocked(
    Map<String, dynamic> locks,
    String group,
    String field,
  ) => (group.isEmpty ? locks[field] : _map(locks[group])[field]) == true;
  static String _selectionFor(String configuration) => switch (configuration) {
    '3_WDG_LV_HV_MAIN_OUTER' => '3 Wdg (LV, HV-Main and Outer)',
    '4_WDG_LV_HV_MAIN_CORSE_OUTER' => '4 Wdg (LV, HV-Main, Corse and Outer)',
    '4_WDG_LV_HV_MAIN_FINE_OUTER' => '4 Wdg (LV, HV-Main, Fine and Outer)',
    '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER' =>
      '5 Wdg (LV, HV-Main, Corse, Fine and Outer)',
    _ => '2 Wdg (LV and HV-Main)',
  };
  static Map<String, dynamic> _normalizeLocks(Map<String, dynamic> source) {
    final locks = <String, dynamic>{...source};
    locks['coreLock'] = <String, dynamic>{
      'coreDia': false,
      'limbHt': false,
      ..._map(source['coreLock']),
    };
    for (final group in _lockGroupByWinding.values) {
      locks[group] = <String, dynamic>{
        'turnsPerPhase': false,
        'conductorSizes': false,
        'noInParallel': false,
        'condBreadth': false,
        'condHeight': false,
        ..._map(source[group]),
      };
    }
    return locks;
  }

  void _setState(MultiWindingState value) {
    _state = value;
    notifyListeners();
  }
}
