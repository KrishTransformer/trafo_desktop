import 'dart:convert';

class MultiWindingDesign {
  MultiWindingDesign._(this._json);

  factory MultiWindingDesign.initial() => MultiWindingDesign._(_defaults());

  factory MultiWindingDesign.fromJson(Map<String, dynamic> json) {
    final merged = _merge(_defaults(), json);
    if (merged['frequency'] == null || merged['frequency'] == '') {
      merged['frequency'] = '50';
    }
    if (merged['topOilTemp'] == null || merged['topOilTemp'] == '') {
      merged['topOilTemp'] = '50';
    }
    return MultiWindingDesign._(merged);
  }

  final Map<String, dynamic> _json;

  Map<String, dynamic> toJson() => _clone(_json);

  Object? readPath(String path) {
    Object? current = _json;
    for (final segment in path.split('.')) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  String textAt(String path) => readPath(path)?.toString() ?? '';

  MultiWindingDesign copyWithPath(String path, Object? value) {
    final next = toJson();
    _writePath(next, path, value);
    return MultiWindingDesign._(next);
  }

  MultiWindingDesign copyWithJson(Map<String, dynamic> json) =>
      MultiWindingDesign._(_clone(json));

  static Map<String, dynamic> _defaults() => <String, dynamic>{
    'windingConfiguration': '2_WDG_LV_HV_MAIN',
    'kVA': '',
    'kValue': '0.45',
    'frequency': '50',
    'primaryVoltage': '433',
    'secondaryVoltage': '11000',
    'vectorGroup': 'Dyn11',
    'buildFactor': '1.3',
    'fluxDensity': '1.6888',
    'revisedVoltsPerTurn': '',
    'revisedFluxDensity': '',
    'limitW': '',
    'limitEz': '',
    'loadLoss': '',
    'coreLoss': '',
    'ambientTemp': '',
    'windingTemp': '',
    'topOilTemp': '50',
    'eRadiatorType': 'RADIATOR',
    'isOLTC': false,
    'tapStepsPercent': '2.5',
    'tapStepsPositive': '2',
    'tapStepsNegative': '2',
    'lvWindingType': 'HELICAL',
    'hvWindingType': 'HELICAL',
    'corseWindingType': 'HELICAL',
    'fineWindingType': 'HELICAL',
    'outerWindingType': 'HELICAL',
    'lvCurrentDensity': '4.24',
    'hvCurrentDensity': '4.24',
    'corseCurrentDensity': '3.63',
    'fineCurrentDensity': '3.63',
    'outerCurrentDensity': '3.63',
    'lVConductorMaterial': 'Cu',
    'hVConductorMaterial': 'Cu',
    'corseConductorMaterial': 'Cu',
    'fineConductorMaterial': 'Cu',
    'outerConductorMaterial': 'Cu',
    'core': <String, dynamic>{
      'coreDia': '',
      'limbHt': '',
      'coreWeight': '',
      'area': '',
      'coreMaterial': 'NipM4',
      'coreType': 'PRIME',
    },
    'tank': <String, dynamic>{
      'tankLoss': '',
      'wdgToTankGap': '',
      'connectionGap': '',
      'topYokeToCoverGap': '',
      'tankLength': '',
      'tankWidth': '',
      'tankHeight': '',
    },
    'lockedAttributes': _defaultLocks(),
    'part2Windings': <String, dynamic>{
      for (final id in _windingIds) id: _defaultWinding(),
    },
    'coilDimensions': <String, dynamic>{
      'coreGap': '',
      'lvhvgap': '',
      'hvhvgap': '',
      'lvid': '',
      'lvradial': '',
      'lvod': '',
      'hvid': '',
      'hvradial': '',
      'hvod': '',
    },
    'multiCoilDimensions': <String, dynamic>{
      'corse': <String, dynamic>{'id': '', 'radial': '', 'od': ''},
      'fine': <String, dynamic>{'id': '', 'radial': '', 'od': ''},
      'outer': <String, dynamic>{'id': '', 'radial': '', 'od': ''},
      'gaps': <String, dynamic>{
        'hvMainToOuterGap': '',
        'hvMainToCorseGap': '',
        'corseToOuterGap': '',
        'hvMainToFineGap': '',
        'fineToOuterGap': '',
        'corseToFineGap': '',
      },
    },
    'cost': <String, dynamic>{
      'copperCostPerKg': 850,
      'aluminiumCostPerKg': 235,
      'coreCostPerKg': 250,
      'steelCostPerKg': 90,
      'oilCostPerKg': 80,
      'insulationCostPerKg': 170,
      'radiatorCostPerKg': 200,
      'capitalCost': '',
    },
    'performance': <String, dynamic>{
      'noLoadLoss': '',
      'loadLoss': '',
      'impedance': '',
      'nlCurrentPercentage': '',
      'voltsPerTurn': '',
      'kW55': '',
    },
    'tankAndOilFormulas': <String, dynamic>{
      'totalSteelWeight': '',
      'totalOil': '',
      'insulationWeight': '',
      'totalRadiatorWeight': '',
      'transformerWeight': '',
    },
    'multiCost': <String, dynamic>{
      'conductors': <String, dynamic>{
        for (final id in _windingIds)
          id: <String, dynamic>{'weight': '', 'totalCost': ''},
      },
    },
  };

  static const List<String> _windingIds = <String>[
    'lv',
    'hvMain',
    'corse',
    'fine',
    'outer',
  ];

  static Map<String, dynamic> _defaultWinding() => <String, dynamic>{
    'turnsPerPhase': '',
    'condBreadth': '',
    'condHeight': '',
    'conductorDiameter': '',
    'radialParallelCond': '',
    'axialParallelCond': '',
    'noOfLayers': '',
    'ducts': '',
    'ductSize': '',
    'condInsulation': '',
    'isConductorRound': false,
    'isEnamel': false,
    'interLayerInsulation': '',
    'endClearances': '',
  };

  static Map<String, dynamic> _defaultLocks() => <String, dynamic>{
    'coreLock': <String, dynamic>{'coreDia': false, 'limbHt': false},
    for (final group in <String>[
      'lvWindings',
      'hvWindings',
      'corseWindings',
      'fineWindings',
      'outerWindings',
    ])
      group: <String, dynamic>{
        'turnsPerPhase': false,
        'conductorSizes': false,
        'noInParallel': false,
        'condBreadth': false,
        'condHeight': false,
      },
  };

  static Map<String, dynamic> _clone(Map<Object?, Object?> source) =>
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

  static Map<String, dynamic> _merge(
    Map<String, dynamic> defaults,
    Map<String, dynamic> values,
  ) {
    final result = _clone(defaults);
    for (final entry in values.entries) {
      final existing = result[entry.key];
      final value = entry.value;
      if (existing is Map && value is Map) {
        result[entry.key] = _merge(
          Map<String, dynamic>.from(existing),
          Map<String, dynamic>.from(value),
        );
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  static void _writePath(
    Map<String, dynamic> target,
    String path,
    Object? value,
  ) {
    final segments = path.split('.');
    var current = target;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (index == segments.length - 1) {
        current[segment] = value;
        return;
      }
      current =
          current.putIfAbsent(segment, () => <String, dynamic>{})
              as Map<String, dynamic>;
    }
  }
}
