import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/network/api_exception.dart';
import '../../home/domain/models/design_summary.dart';
import '../domain/models/two_winding_design.dart';
import '../domain/models/two_winding_metadata.dart';
import '../domain/repositories/two_winding_calculation_repository.dart';
import '../domain/repositories/two_winding_design_repository.dart';
import 'two_winding_state.dart';

class TwoWindingController extends ChangeNotifier {
  TwoWindingController({
    required String routeId,
    required TwoWindingCalculationRepository calculationRepository,
    required TwoWindingDesignRepository designRepository,
    Random? random,
  }) : _routeId = routeId,
       _calculationRepository = calculationRepository,
       _designRepository = designRepository,
       _random = random ?? Random(),
       _state = TwoWindingState.initial(routeId: routeId),
       _baselineDesign = TwoWindingDesign.initial();

  final String _routeId;
  final TwoWindingCalculationRepository _calculationRepository;
  final TwoWindingDesignRepository _designRepository;
  final Random _random;

  TwoWindingState _state;
  TwoWindingDesign _baselineDesign;
  String? _pendingHoveredCommentKey;
  bool _hoverCommentUpdateScheduled = false;
  bool _isDisposed = false;

  TwoWindingState get state => _state;

  Future<void> initialize({DesignSummary? initialSummary}) async {
    if (_state.isInitialized) {
      return;
    }

    // The new-design route must never inherit a saved entity or its results.
    final summary = _routeId == 'new' ? null : initialSummary;
    final design = _buildInitialDesign(summary);
    final metadata = TwoWindingMetadata(
      routeId: _routeId,
      entityId: summary?.id ?? (_routeId == 'new' ? '' : _routeId),
      designId: summary?.designId ?? design.stringAt('designId'),
      createdAt: summary?.createdAt ?? '',
    );

    _baselineDesign = design;
    _setState(
      _state.copyWith(
        isInitialized: true,
        design: design,
        metadata: metadata,
        errorMessage: '',
      ),
    );
  }

  void setField(String path, Object? value) {
    var nextDesign = _state.design.copyWithPath(path, _normalizeValue(value));
    nextDesign = _applyBehaviorRules(
      current: _state.design,
      next: nextDesign,
      changedPath: path,
      value: value,
    );

    _setState(_state.copyWith(design: nextDesign, errorMessage: ''));
  }

  void toggleLock(String path) {
    final lockPath = 'lockedAttributes.$path';
    final currentValue = _state.design.boolAt(lockPath);
    final nextValue = !currentValue;
    var nextDesign = _state.design;

    final segments = path.split('.');
    if (segments.length == 2) {
      final section = segments.first;
      final field = segments.last;

      if ((section == 'innerWindings' || section == 'outerWindings') &&
          field == 'conductorSizes' &&
          nextValue &&
          nextDesign.boolAt('lockedAttributes.coreLock.limbHt')) {
        return;
      }

      nextDesign = nextDesign.copyWithPath(lockPath, nextValue);

      if (field == 'conductorSizes') {
        nextDesign = nextDesign
            .copyWithPath('lockedAttributes.$section.condBreadth', nextValue)
            .copyWithPath('lockedAttributes.$section.condHeight', nextValue);
      }

      if ((field == 'conductorSizes' || field == 'noInParallel') && nextValue) {
        final opposingField = field == 'conductorSizes'
            ? 'noInParallel'
            : 'conductorSizes';
        nextDesign = nextDesign.copyWithPath(
          'lockedAttributes.$section.$opposingField',
          false,
        );
      }
    } else {
      nextDesign = nextDesign.copyWithPath(lockPath, nextValue);
    }

    if (nextDesign.boolAt('lockedAttributes.coreLock.coreDia') &&
        nextDesign.boolAt('lockedAttributes.coreLock.limbHt')) {
      nextDesign = nextDesign
          .copyWithPath('lockedAttributes.innerWindings.noInParallel', false)
          .copyWithPath('lockedAttributes.outerWindings.noInParallel', false);
    }

    _setState(_state.copyWith(design: nextDesign));
  }

  void showComment(String key) {
    if (_state.hoveredCommentKey == key && _pendingHoveredCommentKey == null) {
      return;
    }
    _queueHoveredCommentUpdate(key);
  }

  void clearComment() {
    if (_state.hoveredCommentKey.isEmpty && _pendingHoveredCommentKey == null) {
      return;
    }
    _queueHoveredCommentUpdate('');
  }

  void toggleMoreInfo() {
    _setState(_state.copyWith(expandedMoreInfo: !_state.expandedMoreInfo));
  }

  void reset() {
    _setState(
      _state.copyWith(
        design: _baselineDesign,
        hoveredCommentKey: '',
        errorMessage: '',
      ),
    );
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }
    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<bool> calculate() async {
    if (_state.isCalculating) {
      return false;
    }

    _setState(_state.copyWith(isCalculating: true, errorMessage: ''));

    try {
      final request = TwoWindingDesign.fromJson(
        _buildCalculatePayload(_state.design),
      );
      final calculated = await _calculationRepository.calculate(request);
      final generatedDesignId = _generateDesignId(calculated);
      final persistedDesign = calculated.copyWithPath(
        'designId',
        generatedDesignId,
      );
      _baselineDesign = persistedDesign;
      _setState(
        _state.copyWith(
          design: persistedDesign,
          metadata: _state.metadata.copyWith(designId: generatedDesignId),
        ),
      );

      try {
        final entityId = await _designRepository.createDesign(
          designId: generatedDesignId,
          design: persistedDesign,
        );

        _setState(
          _state.copyWith(
            isCalculating: false,
            metadata: _state.metadata.copyWith(entityId: entityId),
          ),
        );
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
          errorMessage: 'Unable to calculate the two-winding design.',
        ),
      );
      return false;
    }
  }

  String buildPersistentComments() {
    final parts = <String>[];

    if (_state.design.stringAt('lvWindingType') == 'DISC') {
      parts.add(
        'LV Wdg - Spacer Width: '
        '${_displayValue(_state.design.readPath('lvFormulas.lvWidthOfSpacer'))}, '
        'No. of Spacers: '
        '${_displayValue(_state.design.readPath('lvFormulas.lvNoOfSpacers'))}',
      );
    }

    if (_state.design.stringAt('hvWindingType') == 'DISC') {
      parts.add(
        'HV Wdg - Spacer Width: '
        '${_displayValue(_state.design.readPath('hvFormulas.hvWidthOfSpacer'))}, '
        'No. of Spacers: '
        '${_displayValue(_state.design.readPath('hvFormulas.hvNoOfSpacers'))}',
      );
    }

    return parts.join('\n');
  }

  TwoWindingDesign _buildInitialDesign(DesignSummary? initialSummary) {
    if (initialSummary == null || initialSummary.twoWindings == null) {
      return TwoWindingDesign.initial();
    }

    final raw = initialSummary.twoWindings;
    if (raw is Map<String, dynamic>) {
      return TwoWindingDesign.fromJson(raw);
    }
    if (raw is Map<Object?, Object?>) {
      return TwoWindingDesign.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<Object?, Object?>) {
          return TwoWindingDesign.fromJson(Map<String, dynamic>.from(decoded));
        }
      } on FormatException {
        return TwoWindingDesign.initial();
      }
    }

    return TwoWindingDesign.initial();
  }

  TwoWindingDesign _applyBehaviorRules({
    required TwoWindingDesign current,
    required TwoWindingDesign next,
    required String changedPath,
    required Object? value,
  }) {
    switch (changedPath) {
      case 'dryType':
        final isDryType = _toBool(value);
        final dryTempClass = next.stringAt('dryTempClass').isEmpty
            ? 'CLASS_B'
            : next.stringAt('dryTempClass');
        next = next.copyWithPath('dryType', isDryType);
        if (isDryType) {
          next = next
              .copyWithPath('dryTempClass', dryTempClass)
              .copyWithPath(
                'windingTemp',
                _temperatureForDryClass(dryTempClass),
              );
        }
        return next;

      case 'dryTempClass':
        return next.copyWithPath(
          'windingTemp',
          _temperatureForDryClass(next.stringAt('dryTempClass')),
        );

      case 'eTransCostType':
        return _applyCostTypeDefaults(next);

      case 'kVA':
        return _applyKvaDefaults(next, value);

      case 'fluxDensity':
        return _applyFluxDensityClamp(current, next, value);

      case 'vectorGroup':
        return _resetForVectorGroupChange(next, value);

      case 'tapStepsPercent':
      case 'tapStepsPositive':
      case 'tapStepsNegative':
        return next.copyWithPath(
          'outerWindings',
          TwoWindingDesign.initial().mapAt('outerWindings'),
        );

      case 'core.coreDia':
      case 'core.limbHt':
        return _resetForCoreGeometryChange(current, next, changedPath);

      case 'innerWindings.isEnamel':
        return next.copyWithPath('innerWindings.condInsulation', '');

      case 'outerWindings.isEnamel':
        return next.copyWithPath('outerWindings.condInsulation', '');

      case 'innerWindings.radialParallelCond':
      case 'innerWindings.axialParallelCond':
        if (!next.boolAt('lockedAttributes.innerWindings.conductorSizes')) {
          next = next
              .copyWithPath('innerWindings.condBreadth', '')
              .copyWithPath('innerWindings.condHeight', '');
        }
        return next;

      case 'outerWindings.radialParallelCond':
      case 'outerWindings.axialParallelCond':
        if (!next.boolAt('lockedAttributes.outerWindings.conductorSizes')) {
          next = next
              .copyWithPath('outerWindings.condBreadth', '')
              .copyWithPath('outerWindings.condHeight', '');
        }
        return next;

      case 'innerWindings.noOfLayers':
        if (!next.boolAt('lockedAttributes.innerWindings.noInParallel')) {
          next = next
              .copyWithPath('innerWindings.noInParallel', '')
              .copyWithPath('innerWindings.radialParallelCond', '')
              .copyWithPath('innerWindings.axialParallelCond', '');
        }
        return next;

      case 'outerWindings.noOfLayers':
        if (!next.boolAt('lockedAttributes.outerWindings.noInParallel')) {
          next = next
              .copyWithPath('outerWindings.noInParallel', '')
              .copyWithPath('outerWindings.radialParallelCond', '')
              .copyWithPath('outerWindings.axialParallelCond', '');
        }
        return next;

      case 'outerWindings.conductorDiameter':
        if (next.boolAt('outerWindings.isConductorRound')) {
          final diameter = next.stringAt('outerWindings.conductorDiameter');
          next = next
              .copyWithPath('outerWindings.condBreadth', diameter)
              .copyWithPath('outerWindings.condHeight', diameter);
        }
        return next;
    }

    return next;
  }

  TwoWindingDesign _applyCostTypeDefaults(TwoWindingDesign design) {
    final next = design.toJson();
    final costType = design.stringAt('eTransCostType');
    final lvMaterial = design.stringAt('lVConductorMaterial');
    final hvMaterial = design.stringAt('hVConductorMaterial');

    next['lvCurrentDensity'] = _currentDensityFor(
      costType: costType,
      conductorMaterial: lvMaterial,
    );
    next['hvCurrentDensity'] = _currentDensityFor(
      costType: costType,
      conductorMaterial: hvMaterial,
    );

    return design.copyWithJson(next);
  }

  TwoWindingDesign _applyKvaDefaults(
    TwoWindingDesign design,
    Object? rawValue,
  ) {
    final kVa = _toDouble(rawValue);
    if (kVa == null) {
      return design;
    }

    final next = design.toJson();
    next['kVA'] = _normalizeValue(rawValue);

    if (kVa <= 2500) {
      next['highVoltage'] = 11000;
      next['lowVoltage'] = 433;
      next['hvWindingType'] = 'HELICAL';
      next['lvWindingType'] = 'HELICAL';
      next['fluxDensity'] = 1.7333;
    } else if (kVa <= 20000) {
      next['highVoltage'] = 33000;
      next['lowVoltage'] = 11000;
      next['hvWindingType'] = 'DISC';
      next['lvWindingType'] = 'HELICAL';
      next['fluxDensity'] = 1.69;
    } else {
      next['highVoltage'] = 132000;
      next['lowVoltage'] = 33000;
      next['hvWindingType'] = 'DISC';
      next['lvWindingType'] = 'DISC';
      next['fluxDensity'] = 1.69;
    }

    return design.copyWithJson(next);
  }

  TwoWindingDesign _applyFluxDensityClamp(
    TwoWindingDesign current,
    TwoWindingDesign design,
    Object? rawValue,
  ) {
    final fluxDensity = _toDouble(rawValue);
    final kVa = _toDouble(design.readPath('kVA')) ?? 0;
    if (fluxDensity == null) {
      return design;
    }

    final maxValue = kVa <= 2500 ? 1.7333 : 1.69;
    final next = design.toJson();
    next['fluxDensity'] = fluxDensity > maxValue ? maxValue : fluxDensity;

    return _resetSharedDownstreamState(
      current: current,
      next: design.copyWithJson(next),
      preserveCoreLocks: true,
    );
  }

  TwoWindingDesign _resetForVectorGroupChange(
    TwoWindingDesign design,
    Object? rawValue,
  ) {
    final next = design.toJson();
    next['vectorGroup'] = _normalizeValue(rawValue);
    return _resetSharedDownstreamState(
      current: _state.design,
      next: design.copyWithJson(next),
      preserveCoreLocks: false,
    );
  }

  TwoWindingDesign _resetForCoreGeometryChange(
    TwoWindingDesign current,
    TwoWindingDesign design,
    String changedPath,
  ) {
    final next = design.toJson();
    final changedValue = design.readPath(changedPath);
    final initial = TwoWindingDesign.initial();

    next['innerWindings'] = <String, dynamic>{
      ...initial.mapAt('innerWindings'),
      if (current.boolAt('lockedAttributes.innerWindings.turnsPerPhase'))
        'turnsPerPhase': current.stringAt('innerWindings.turnsPerPhase'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'conductorSizes': current.stringAt('innerWindings.conductorSizes'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'condBreadth': current.stringAt('innerWindings.condBreadth'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'condHeight': current.stringAt('innerWindings.condHeight'),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'noInParallel': current.stringAt('innerWindings.noInParallel'),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'radialParallelCond': current.stringAt(
          'innerWindings.radialParallelCond',
        ),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'axialParallelCond': current.stringAt(
          'innerWindings.axialParallelCond',
        ),
    };
    next['outerWindings'] = <String, dynamic>{
      ...initial.mapAt('outerWindings'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'conductorSizes': current.stringAt('outerWindings.conductorSizes'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'condBreadth': current.stringAt('outerWindings.condBreadth'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'condHeight': current.stringAt('outerWindings.condHeight'),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'noInParallel': current.stringAt('outerWindings.noInParallel'),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'radialParallelCond': current.stringAt(
          'outerWindings.radialParallelCond',
        ),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'axialParallelCond': current.stringAt(
          'outerWindings.axialParallelCond',
        ),
    };
    next['tankLoss'] = '';
    next['coilDimensions'] = <String, dynamic>{
      ...initial.mapAt('coilDimensions'),
      'coreGap': current.stringAt('coilDimensions.coreGap'),
      'lvhvgap': current.stringAt('coilDimensions.lvhvgap'),
      'hvhvgap': current.stringAt('coilDimensions.hvhvgap'),
    };

    if (changedPath == 'core.coreDia') {
      next['core'] = <String, dynamic>{
        ...design.mapAt('core'),
        'coreDia': changedValue,
      };
    } else {
      next['core'] = <String, dynamic>{
        ...design.mapAt('core'),
        'limbHt': changedValue,
      };
    }

    return design.copyWithJson(next);
  }

  TwoWindingDesign _resetSharedDownstreamState({
    required TwoWindingDesign current,
    required TwoWindingDesign next,
    required bool preserveCoreLocks,
  }) {
    final initial = TwoWindingDesign.initial();
    final json = next.toJson();

    json['innerWindings'] = <String, dynamic>{
      ...initial.mapAt('innerWindings'),
      if (current.boolAt('lockedAttributes.innerWindings.turnsPerPhase'))
        'turnsPerPhase': current.stringAt('innerWindings.turnsPerPhase'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'conductorSizes': current.stringAt('innerWindings.conductorSizes'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'condBreadth': current.stringAt('innerWindings.condBreadth'),
      if (current.boolAt('lockedAttributes.innerWindings.conductorSizes'))
        'condHeight': current.stringAt('innerWindings.condHeight'),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'noInParallel': current.stringAt('innerWindings.noInParallel'),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'radialParallelCond': current.stringAt(
          'innerWindings.radialParallelCond',
        ),
      if (current.boolAt('lockedAttributes.innerWindings.noInParallel'))
        'axialParallelCond': current.stringAt(
          'innerWindings.axialParallelCond',
        ),
    };

    json['outerWindings'] = <String, dynamic>{
      ...initial.mapAt('outerWindings'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'conductorSizes': current.stringAt('outerWindings.conductorSizes'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'condBreadth': current.stringAt('outerWindings.condBreadth'),
      if (current.boolAt('lockedAttributes.outerWindings.conductorSizes'))
        'condHeight': current.stringAt('outerWindings.condHeight'),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'noInParallel': current.stringAt('outerWindings.noInParallel'),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'radialParallelCond': current.stringAt(
          'outerWindings.radialParallelCond',
        ),
      if (current.boolAt('lockedAttributes.outerWindings.noInParallel'))
        'axialParallelCond': current.stringAt(
          'outerWindings.axialParallelCond',
        ),
    };

    json['tankLoss'] = '';
    json['coilDimensions'] = <String, dynamic>{
      ...initial.mapAt('coilDimensions'),
      'coreGap': current.stringAt('coilDimensions.coreGap'),
      'lvhvgap': current.stringAt('coilDimensions.lvhvgap'),
      'hvhvgap': current.stringAt('coilDimensions.hvhvgap'),
    };
    json['core'] = <String, dynamic>{
      ...initial.mapAt('core'),
      'coreMaterial': current.stringAt('core.coreMaterial'),
      if (preserveCoreLocks &&
          current.boolAt('lockedAttributes.coreLock.coreDia'))
        'coreDia': current.readPath('core.coreDia'),
      if (preserveCoreLocks &&
          current.boolAt('lockedAttributes.coreLock.limbHt'))
        'limbHt': current.readPath('core.limbHt'),
    };

    return next.copyWithJson(json);
  }

  Map<String, dynamic> _buildCalculatePayload(TwoWindingDesign design) {
    final payload = design.toJson();
    if (payload['frequency'] == null ||
        payload['frequency'].toString().trim().isEmpty) {
      payload['frequency'] = 50;
    }
    if (payload['topOilTemp'] == null ||
        payload['topOilTemp'].toString().trim().isEmpty) {
      payload['topOilTemp'] = 50;
    }
    final lockedAttributes = design.mapAt('lockedAttributes');

    final innerLocks =
        lockedAttributes['innerWindings'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final outerLocks =
        lockedAttributes['outerWindings'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final coreLocks =
        lockedAttributes['coreLock'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    final innerWindings =
        payload['innerWindings'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final outerWindings =
        payload['outerWindings'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final core =
        payload['core'] as Map<String, dynamic>? ?? <String, dynamic>{};

    for (final entry in innerLocks.entries) {
      if (entry.value == false && innerWindings.containsKey(entry.key)) {
        innerWindings[entry.key] = null;
      }
    }

    for (final entry in outerLocks.entries) {
      if (entry.value == false && outerWindings.containsKey(entry.key)) {
        outerWindings[entry.key] = null;
      }
    }

    for (final entry in coreLocks.entries) {
      if (entry.value == false && core.containsKey(entry.key)) {
        core[entry.key] = null;
      }
    }

    payload['innerWindings'] = innerWindings;
    payload['outerWindings'] = outerWindings;
    payload['core'] = core;
    payload['lockedAttributes'] = lockedAttributes;
    _sanitizeCalculatePayload(payload);
    return payload;
  }

  void _sanitizeCalculatePayload(Map<String, dynamic> payload) {
    const numericPaths = <String>[
      'kVA',
      'lowVoltage',
      'highVoltage',
      'lvCurrentDensity',
      'hvCurrentDensity',
      'buildFactor',
      'fluxDensity',
      'frequency',
      'tapStepsPercent',
      'tapStepsPositive',
      'tapStepsNegative',
      'kValue',
      'limitEz',
      'ambientTemp',
      'windingTemp',
      'topOilTemp',
      'radiatorWidth',
      'core.coreDia',
      'core.limbHt',
      'core.cenDist',
      'core.area',
      'core.wkgGrade',
      'core.wKgGrade',
      'core.fluxDensity',
      'core.coreWeight',
      'tank.tankLength',
      'tank.tankWidth',
      'tank.tankHeight',
      'tank.tankCapacity',
      'tank.tankWallThickness',
      'tank.tankLidThickness',
      'tank.tankBottomThickness',
      'tank.frameThickness',
      'tank.tankLoss',
      'tank.wdgToTankGap',
      'tank.connectionGap',
      'tank.topYokeToCoverGap',
      'coilDimensions.coreDia',
      'coilDimensions.coreGap',
      'coilDimensions.lvid',
      'coilDimensions.lVID',
      'coilDimensions.lvradial',
      'coilDimensions.lVRadial',
      'coilDimensions.lvod',
      'coilDimensions.lVOD',
      'coilDimensions.lvhvgap',
      'coilDimensions.lVHVGap',
      'coilDimensions.hvid',
      'coilDimensions.hVID',
      'coilDimensions.hvradial',
      'coilDimensions.hVRadial',
      'coilDimensions.hvod',
      'coilDimensions.hVOD',
      'coilDimensions.hvhvgap',
      'coilDimensions.hVHVGap',
      'cost.copperCostPerKg',
      'cost.aluminiumCostPerKg',
      'cost.coreCostPerKg',
      'cost.steelCostPerKg',
      'cost.oilCostPerKg',
      'cost.insulationCostPerKg',
      'cost.radiatorCostPerKg',
      'cost.totalCondCost',
      'cost.totalCoreCost',
      'cost.totalSteelCost',
      'cost.totalOilCost',
      'cost.totalInsCost',
      'cost.totalRadiatorCost',
      'cost.capitalCost',
    ];

    for (final path in numericPaths) {
      _nullInvalidNumberAt(payload, path);
    }

    for (final section in ['innerWindings', 'outerWindings']) {
      for (final field in _windingNumericFields) {
        _nullInvalidNumberAt(payload, '$section.$field');
      }
      _nullInvalidBoolAt(payload, '$section.isConductorRound');
      _nullInvalidBoolAt(payload, '$section.isEnamel');
    }

    for (final path in ['dryTempClass', 'lvTerminalType', 'hvTerminalType']) {
      _nullEmptyStringAt(payload, path);
    }
  }

  static const List<String> _windingNumericFields = <String>[
    'turnsPerPhase',
    'phaseCurrent',
    'currentDensity',
    'condCrossSec',
    'condInsulation',
    'windingLength',
    'noOfLayers',
    'turnsPerLayer',
    'terminal',
    'endClearances',
    'eddyStrayLoss',
    'tempGradDegC',
    'ducts',
    'ductSize',
    'discDuctSize',
    'insulatedWeight',
    'bareWeight',
    'loadLoss',
    'commRawCond',
    'interLayerInsulation',
    'radialParallelCond',
    'axialParallelCond',
    'condBreadth',
    'condHeight',
    'conductorDiameter',
  ];

  void _nullInvalidNumberAt(Map<String, dynamic> payload, String path) {
    final parent = _parentMapForPath(payload, path);
    if (parent == null) {
      return;
    }
    final key = path.split('.').last;
    final value = parent[key];
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || double.tryParse(text) == null) {
        parent[key] = null;
      }
    }
  }

  void _nullEmptyStringAt(Map<String, dynamic> payload, String path) {
    final parent = _parentMapForPath(payload, path);
    if (parent == null) {
      return;
    }
    final key = path.split('.').last;
    final value = parent[key];
    if (value is String && value.trim().isEmpty) {
      parent[key] = null;
    }
  }

  void _nullInvalidBoolAt(Map<String, dynamic> payload, String path) {
    final parent = _parentMapForPath(payload, path);
    if (parent == null) {
      return;
    }
    final key = path.split('.').last;
    final value = parent[key];
    if (value is String && value.trim().isEmpty) {
      parent[key] = null;
    }
  }

  Map<String, dynamic>? _parentMapForPath(
    Map<String, dynamic> payload,
    String path,
  ) {
    final segments = path.split('.');
    Object? current = payload;
    for (final segment in segments.take(segments.length - 1)) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current is Map<String, dynamic> ? current : null;
  }

  String _generateDesignId(TwoWindingDesign design) {
    final rawKva = design.readPath('kVA');
    final kVaText = _displayValue(rawKva);
    final suffix = 10000 + _random.nextInt(90000);
    return '${kVaText.isEmpty ? '0' : kVaText}k-$suffix';
  }

  String _temperatureForDryClass(String dryClass) {
    return switch (dryClass) {
      'CLASS_B' => '70',
      'CLASS_F' => '90',
      'CLASS_H' => '115',
      _ => '70',
    };
  }

  String _currentDensityFor({
    required String costType,
    required String conductorMaterial,
  }) {
    final isCopper = conductorMaterial == 'Cu';
    return switch (costType) {
      'ENERGY_EFFICIENT' => isCopper ? '1.7' : '0.9',
      _ => isCopper ? '4.24' : '2.37',
    };
  }

  bool _toBool(Object? value) {
    return switch (value) {
      true => true,
      'true' => true,
      'on' => true,
      _ => false,
    };
  }

  double? _toDouble(Object? value) {
    return switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
  }

  Object? _normalizeValue(Object? value) {
    if (value is String) {
      return value;
    }
    return value;
  }

  String _displayValue(Object? value) {
    if (value == null) {
      return '-';
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  void _setState(TwoWindingState nextState) {
    if (_isDisposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  void _queueHoveredCommentUpdate(String key) {
    _pendingHoveredCommentKey = key;
    if (_hoverCommentUpdateScheduled) {
      return;
    }

    _hoverCommentUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) {
        _pendingHoveredCommentKey = null;
        _hoverCommentUpdateScheduled = false;
        return;
      }
      _hoverCommentUpdateScheduled = false;
      final nextKey = _pendingHoveredCommentKey;
      _pendingHoveredCommentKey = null;
      if (nextKey == null || nextKey == _state.hoveredCommentKey) {
        return;
      }

      _setState(_state.copyWith(hoveredCommentKey: nextKey));
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pendingHoveredCommentKey = null;
    _hoverCommentUpdateScheduled = false;
    super.dispose();
  }
}
