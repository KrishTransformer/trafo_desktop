import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
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

      _setState(
        _state.copyWith(
          design: calculated,
          designId: generatedId,
        ),
      );

      try {
        await _designRepository.createDesign(
          designId: generatedId,
          design: calculated,
        );
        _setState(_state.copyWith(isCalculating: false));
      } on ApiException catch (exception) {
        _setState(
          _state.copyWith(
            isCalculating: false,
            errorMessage:
                'Calculated values are shown, but saving the design failed. '
                '${exception.message}',
          ),
        );
        return false;
      }
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isCalculating: false, errorMessage: exception.message),
      );
      return false;
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
    final core = _map(source['core']);
    final tank = _map(source['tank']);
    final radialGaps = _buildRadialGaps(source, configuration);
    final payload = <String, dynamic>{
      'designId': _nullable(source['designId']),
      'windingSelection': _selectionFor(configuration),
      'kVA': _integer(source['kVA']),
      'kValue': _number(source['kValue']) ?? 0.45,
      'frequency': _number(source['frequency']) ?? 50,
      'fluxDensity': _number(source['fluxDensity']),
      'vectorGroup': _nullable(source['vectorGroup']),
      'buildFactor': _number(source['buildFactor']),
      'limitW': _number(source['limitW']),
      'limitEz': _number(source['limitEz']),
      'tankLoss': _number(tank['tankLoss']),
      'loadLoss': _number(source['loadLoss']),
      'coreLoss': _number(source['coreLoss']),
      'ambientTemp': _number(source['ambientTemp']),
      'windingTemp': _number(source['windingTemp']),
      'topOilTemp': _number(source['topOilTemp']) ?? 50,
      'eRadiatorType': _nullable(source['eRadiatorType']),
      'isOLTC': source['isOLTC'] == true,
      'lowVoltage': _integer(source['primaryVoltage'] ?? source['lowVoltage']),
      'highVoltage': _integer(
        source['secondaryVoltage'] ?? source['highVoltage'],
      ),
      'tapStepsPercentage': _number(source['tapStepsPercent']),
      'tapStepPositive': _integer(source['tapStepsPositive']),
      'tapStepNegative': _integer(source['tapStepsNegative']),
      'core': <String, dynamic>{
        'coreDia': _isLocked(locks, 'coreLock', 'coreDia')
            ? _integer(core['coreDia'])
            : null,
        'limbHt': _isLocked(locks, 'coreLock', 'limbHt')
            ? _integer(core['limbHt'])
            : null,
        'coreMaterial': _nullable(core['coreMaterial']),
        'coreType': _nullable(core['coreType']),
      },
      'tank': <String, dynamic>{
        'tankLoss': _number(tank['tankLoss']),
        'wdgToTankGap': _number(tank['wdgToTankGap']),
        'connectionGap': _number(tank['connectionGap']),
        'topYokeToCoverGap': _number(tank['topYokeToCoverGap']),
      },
      'lockedAttributes': locks,
      'cost': _map(source['cost']),
      'radialGaps': radialGaps,
      ...radialGaps,
    };
    for (final windingId in active) {
      final apiKey = _lockGroupByWinding[windingId]!;
      final prefix = windingId == 'hvMain' ? 'hv' : windingId;
      final windingType = _text(source['${prefix}WindingType']);
      payload['${prefix}WindingType'] = _nullable(
        source['${prefix}WindingType'],
      );
      payload['${prefix}CurrentDensity'] = _number(
        source['${prefix}CurrentDensity'],
      );
      final materialField = windingId == 'lv'
          ? 'lVConductorMaterial'
          : windingId == 'hvMain'
          ? 'hVConductorMaterial'
          : '${prefix}ConductorMaterial';
      payload['${prefix}ConductorMaterial'] = _materialCode(
        source[materialField],
      );
      payload[apiKey] = _buildWinding(
        _map(windingData[windingId]),
        _map(locks[apiKey]),
        windingType,
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
    return <String, dynamic>{for (final key in active) key: _number(all[key])};
  }

  Map<String, dynamic> _buildWinding(
    Map<String, dynamic> winding,
    Map<String, dynamic> locks,
    String windingType,
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
    'noOfLayers': _number(winding['noOfLayers']),
    'ducts': _integer(winding['ducts']),
    'ductSize': _resolvedDuctSize(winding, windingType),
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

  static int? _resolvedDuctSize(
    Map<String, dynamic> winding,
    String windingType,
  ) {
    final source = windingType == 'DISC'
        ? winding['discDuctSize'] ?? winding['ductSize']
        : winding['ductSize'];
    return _integer(source);
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
    final common = _map(results['common']);
    final impedance = _map(results['impedance']);
    final responseLocks = _map(response['lockedAttributes']);
    final responseEz = _map(results['ez']);
    final phaseVoltages = _map(results['phaseVoltages']);
    final phaseVoltageDivision = _map(results['phaseVoltageDivision']);
    final lvWinding = _map(results['lvWinding']);
    final hvWinding = _map(results['hvWinding']);
    final corseWinding = _map(results['corseWinding']);
    final fineWinding = _map(results['fineWinding']);
    final outerWinding = _map(results['outerWinding']);

    _putIfPresent(
      merged,
      'windingConfiguration',
      _configurationForSelectedCode(_text(response['selectedCode'])),
    );
    _putIfPresent(merged, 'designId', inputs['designId']);

    _putIfPresent(merged, 'kVA', ratings['kVA'] ?? response['kVA']);
    _putIfPresent(merged, 'primaryVoltage', ratings['lowVoltage']);
    _putIfPresent(merged, 'secondaryVoltage', ratings['highVoltage']);
    _putIfPresent(merged, 'fluxDensity', ratings['fluxDensity']);
    _putIfPresent(
      merged,
      'vectorGroup',
      inputs['vectorGroup'] ?? common['vectorGroup'],
    );
    _putIfPresent(merged, 'kValue', ratings['kValue'] ?? common['kValue']);
    _putIfPresent(
      merged,
      'frequency',
      ratings['frequency'] ?? common['frequency'],
    );
    _putIfPresent(
      merged,
      'lowVoltage',
      _pickDefined(<Object?>[
        phaseVoltages['lv'],
        phaseVoltageDivision['lv'],
        lvWinding['voltsPerPhase'],
      ]),
    );
    _putIfPresent(
      merged,
      'highVoltage',
      _pickDefined(<Object?>[
        phaseVoltages['hvMain'],
        phaseVoltageDivision['hvMain'],
        hvWinding['voltsPerPhase'],
      ]),
    );
    _putIfPresent(
      merged,
      'corseVoltage',
      _pickDefined(<Object?>[
        phaseVoltages['corse'],
        phaseVoltageDivision['corse'],
        corseWinding['voltsPerPhase'],
      ]),
    );
    _putIfPresent(
      merged,
      'fineVoltage',
      _pickDefined(<Object?>[
        phaseVoltages['fine'],
        phaseVoltageDivision['fine'],
        fineWinding['voltsPerPhase'],
      ]),
    );
    _putIfPresent(
      merged,
      'outerVoltage',
      _pickDefined(<Object?>[
        phaseVoltages['outer'],
        phaseVoltageDivision['outer'],
        outerWinding['voltsPerPhase'],
      ]),
    );
    _putIfPresent(merged, 'buildFactor', common['buildFactor']);
    _putIfPresent(
      merged,
      'revisedVoltsPerTurn',
      results['revisedVoltsPerTurn'],
    );
    _putIfPresent(merged, 'revisedFluxDensity', results['revisedFluxDensity']);
    _putIfPresent(merged, 'limitEz', responseEz['limit']);
    _putIfPresent(
      merged,
      'ez',
      responseEz['value'] ?? impedance['ek'] ?? common['ek'],
    );
    _putIfPresent(
      merged,
      'coreLoss',
      results['noLoadLoss'] ??
          results['coreLoss'] ??
          common['coreLoss'] ??
          hvWinding['coreLoss'] ??
          lvWinding['coreLoss'],
    );
    _putIfPresent(merged, 'ambientTemp', lvWinding['ambientTemp']);
    _putIfPresent(merged, 'windingTemp', lvWinding['windingTemp']);
    _putIfPresent(
      merged,
      'topOilTemp',
      tankAndOil['topOilTemp'] ??
          tankAndOil['topOilTemperature'] ??
          results['topOilTemp'] ??
          common['topOilTemp'],
    );
    _putIfPresent(merged, 'eRadiatorType', inputs['eRadiatorType']);
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
      'kW55':
          tankAndOil['kw55'] ??
          results['kW55'] ??
          common['kW55'] ??
          _map(merged['performance'])['kW55'],
    };
    merged['tank'] = <String, dynamic>{
      ..._map(merged['tank']),
      'tankLoss': tankAndOil['tankLoss'] ?? _map(merged['tank'])['tankLoss'],
      'wdgToTankGap':
          tankAndOil['wdgTankGap'] ?? _map(merged['tank'])['wdgToTankGap'],
      'connectionGap':
          tankAndOil['connectionGap'] ?? _map(merged['tank'])['connectionGap'],
      'topYokeToCoverGap':
          tankAndOil['topYokeCoverGap'] ??
          _map(merged['tank'])['topYokeToCoverGap'],
      'tankLength':
          tankAndOil['tankLength'] ?? _map(merged['tank'])['tankLength'],
      'tankWidth': tankAndOil['tankWidth'] ?? _map(merged['tank'])['tankWidth'],
      'tankHeight':
          tankAndOil['tankHeight'] ?? _map(merged['tank'])['tankHeight'],
      'tankCapacity':
          tankAndOil['tankCapacity'] ?? _map(merged['tank'])['tankCapacity'],
      'tankDimension':
          tankAndOil['tankDimension'] ?? _map(merged['tank'])['tankDimension'],
      'overallDimension':
          tankAndOil['overallDimension'] ??
          _map(merged['tank'])['overallDimension'],
    };
    merged['tankAndOilFormulas'] = <String, dynamic>{
      ..._map(merged['tankAndOilFormulas']),
      'coolingStatement':
          tankAndOil['coolingStatement'] ??
          _map(merged['tankAndOilFormulas'])['coolingStatement'],
      'conservatorDia':
          tankAndOil['conservatorDia'] ??
          _map(merged['tankAndOilFormulas'])['conservatorDia'],
      'conservatorLength':
          tankAndOil['conservatorLength'] ??
          _map(merged['tankAndOilFormulas'])['conservatorLength'],
      'conservatorCapacity':
          tankAndOil['conservatorCapacity'] ??
          _map(merged['tankAndOilFormulas'])['conservatorCapacity'],
      'totalConductorWeight':
          tankAndOil['totalConductorWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalConductorWeight'],
      'totalConnectionWeight':
          tankAndOil['totalConnectionWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalConnectionWeight'],
      'totalSteelWeight':
          tankAndOil['totalSteelWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalSteelWeight'],
      'totalOil':
          tankAndOil['totalOil'] ??
          _map(merged['tankAndOilFormulas'])['totalOil'],
      'oilWeight':
          tankAndOil['oilWeight'] ??
          _map(merged['tankAndOilFormulas'])['oilWeight'],
      'insulationWeight':
          tankAndOil['insulationWeight'] ??
          _map(merged['tankAndOilFormulas'])['insulationWeight'],
      'totalRadiatorWeight':
          tankAndOil['totalRadiatorWeight'] ??
          _map(merged['tankAndOilFormulas'])['totalRadiatorWeight'],
      'radiatorHeight':
          tankAndOil['radiatorHeight'] ??
          _map(merged['tankAndOilFormulas'])['radiatorHeight'],
      'radiatorWidth':
          tankAndOil['radiatorWidth'] ??
          _map(merged['tankAndOilFormulas'])['radiatorWidth'],
      'radiatorSection':
          tankAndOil['radiatorSection'] ??
          _map(merged['tankAndOilFormulas'])['radiatorSection'],
      'noOfRadiators':
          tankAndOil['noOfRadiators'] ??
          _map(merged['tankAndOilFormulas'])['noOfRadiators'],
      'weightsOfActivePart':
          tankAndOil['weightsOfActivePart'] ??
          _map(merged['tankAndOilFormulas'])['weightsOfActivePart'],
      'weightCore':
          tankAndOil['weightCore'] ??
          _map(merged['tankAndOilFormulas'])['weightCore'],
      'transformerWeight':
          tankAndOil['transformerWeight'] ??
          _map(merged['tankAndOilFormulas'])['transformerWeight'],
      'weightOfTankAndAcc':
          tankAndOil['weightOfTankAndAcc'] ??
          _map(merged['tankAndOilFormulas'])['weightOfTankAndAcc'],
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
      'activePartSize':
          dimensions['activePartSize'] ??
          _map(merged['coilDimensions'])['activePartSize'],
      'centerDistance':
          dimensions['centerDistance'] ??
          _map(merged['coilDimensions'])['centerDistance'],
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
    final windingResults = <String, Map<String, dynamic>>{
      'lv': lvWinding,
      'hvMain': hvWinding,
      'corse': corseWinding,
      'fine': fineWinding,
      'outer': outerWinding,
    };
    for (final entry in windingIds.entries) {
      final result = windingResults[entry.key] ?? <String, dynamic>{};
      final input = _map(inputWindings[entry.value]);
      existingWindings[entry.key] = <String, dynamic>{
        ..._map(existingWindings[entry.key]),
        ..._mergeWindingState(
          input,
          result,
          discDuctSize: entry.key == 'lv'
              ? lvWinding['lvDiscDuctsSize']
              : entry.key == 'hvMain'
              ? hvWinding['hvDiscDuctsSize'] ??
                    _map(hvWinding['model'])['ductSize']
              : null,
        ),
      };
    }
    merged['part2Windings'] = existingWindings;
    final conductorCosts = _map(_map(merged['multiCost'])['conductors']);
    for (final entry in windingIds.entries) {
      final winding = windingResults[entry.key] ?? <String, dynamic>{};
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
      responseLocks.isNotEmpty
          ? responseLocks
          : _map(request['lockedAttributes']),
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

  static Object? _pickDefined(List<Object?> values) {
    for (final value in values) {
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _configurationForSelectedCode(String selectedCode) {
    switch (selectedCode) {
      case '2WDG':
      case '2_WDG':
        return '2_WDG_LV_HV_MAIN';
      case '3_WDG':
        return '3_WDG_LV_HV_MAIN_OUTER';
      case '4_WDG_C':
        return '4_WDG_LV_HV_MAIN_CORSE_OUTER';
      case '4_WDG_F':
        return '4_WDG_LV_HV_MAIN_FINE_OUTER';
      case '5_WDG':
        return '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER';
      default:
        return null;
    }
  }

  static Map<String, dynamic> _mergeWindingState(
    Map<String, dynamic> inputModel,
    Map<String, dynamic> resultModel, {
    Object? discDuctSize,
  }) {
    final formattedConductorSizes =
        resultModel['breadth'] != null && resultModel['height'] != null
        ? '${resultModel['breadth']} L X ${resultModel['height']} B'
        : null;
    return <String, dynamic>{
      'turnsPerPhase': _pickDefined(<Object?>[
        inputModel['turnsPerPhase'],
        resultModel['turnsPerPhase'],
      ]),
      'phaseCurrent': _pickDefined(<Object?>[
        inputModel['phaseCurrent'],
        resultModel['phaseCurrent'],
      ]),
      'currentDensity': _pickDefined(<Object?>[
        inputModel['currentDensity'],
        resultModel['currentDensity'],
      ]),
      'condCrossSec': _pickDefined(<Object?>[
        inputModel['condCrossSec'],
        resultModel['condCrossSec'],
      ]),
      'conductorSizes': _pickDefined(<Object?>[
        inputModel['conductorSizes'],
        formattedConductorSizes,
      ]),
      'condInsulation': _pickDefined(<Object?>[
        inputModel['condInsulation'],
        resultModel['conductorInsulation'],
      ]),
      'noInParallel': _pickDefined(<Object?>[
        inputModel['noInParallel'],
        _formatParallelFromValues(
          resultModel['radialParallelCond'],
          resultModel['axialParallelCond'],
        ),
      ]),
      'windingLength': _pickDefined(<Object?>[
        inputModel['windingLength'],
        resultModel['windingLength'],
      ]),
      'noOfLayers': _pickDefined(<Object?>[
        inputModel['noOfLayers'],
        resultModel['noOfLayers'],
      ]),
      'interLayerInsulation': _pickDefined(<Object?>[
        inputModel['interLayerInsulation'],
        resultModel['interLayerInsulation'],
      ]),
      'ducts': _pickDefined(<Object?>[
        inputModel['ducts'],
        resultModel['ducts'],
      ]),
      'ductSize': _pickDefined(<Object?>[
        inputModel['ductSize'],
        resultModel['ductSize'],
      ]),
      'discDuctSize': _pickDefined(<Object?>[
        discDuctSize,
        inputModel['discDuctSize'],
      ]),
      'turnsLayers': inputModel['turnsLayers'],
      'endClearances': _pickDefined(<Object?>[
        inputModel['endClearances'],
        resultModel['endClearance'],
      ]),
      'eddyStrayLoss': _pickDefined(<Object?>[
        inputModel['eddyStrayLoss'],
        resultModel['strayLoss'],
      ]),
      'tempGradDegC': _pickDefined(<Object?>[
        inputModel['tempGradDegC'],
        resultModel['gradient'],
      ]),
      'weightBareInsulated': _pickDefined(<Object?>[
        inputModel['weightBareInsulated'],
        _formatWeightPair(
          resultModel['bareWeight'],
          resultModel['insulatedWeight'],
        ),
      ]),
      'loadLoss': _pickDefined(<Object?>[
        inputModel['loadLoss'],
        resultModel['loadLoss'],
      ]),
      'radialParallelCond': _pickDefined(<Object?>[
        inputModel['radialParallelCond'],
        resultModel['radialParallelCond'],
      ]),
      'axialParallelCond': _pickDefined(<Object?>[
        inputModel['axialParallelCond'],
        resultModel['axialParallelCond'],
      ]),
      'condBreadth': _pickDefined(<Object?>[
        inputModel['condBreadth'],
        resultModel['breadth'],
      ]),
      'condHeight': _pickDefined(<Object?>[
        inputModel['condHeight'],
        resultModel['height'],
      ]),
      'conductorDiameter': _pickDefined(<Object?>[
        inputModel['conductorDiameter'],
        resultModel['conductorDiameter'],
      ]),
      'isConductorRound': _pickDefined(<Object?>[
        inputModel['isConductorRound'],
        resultModel['isConductorRound'],
      ]),
      'isEnamel': _pickDefined(<Object?>[
        inputModel['isEnamel'],
        resultModel['isEnamel'],
      ]),
    };
  }

  static String? _formatParallelFromValues(Object? radial, Object? axial) {
    if (radial == null && axial == null) {
      return null;
    }
    final radialText = _text(radial);
    final axialText = _text(axial);
    final radialValue = _number(radial);
    final axialValue = _number(axial);
    final total = radialValue != null && axialValue != null
        ? radialValue * axialValue
        : '';
    return 'Rad $radialText X Axi $axialText = $total';
  }

  static String? _formatWeightPair(
    Object? bareWeight,
    Object? insulatedWeight,
  ) {
    if (bareWeight == null && insulatedWeight == null) {
      return null;
    }
    return '${bareWeight ?? ''} / ${insulatedWeight ?? ''}'.trim();
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
  static int? _integer(Object? value) => num.tryParse(_text(value))?.truncate();
  static double? _number(Object? value) => double.tryParse(_text(value));
  static String? _materialCode(Object? value) => switch (_text(value)) {
    'Cu' || 'COPPER' => 'COPPER',
    'Al' || 'ALUMINIUM' => 'ALUMINIUM',
    _ => null,
  };
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
