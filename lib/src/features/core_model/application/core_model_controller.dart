import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../design_workspace/domain/models/core_calculation_request.dart';
import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/core_stack_request_entry.dart';
import '../../design_workspace/domain/models/core_stack_step.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../design_workspace/domain/repositories/core_calculation_repository.dart';
import '../../design_workspace/domain/repositories/core_design_repository.dart';
import '../../home/domain/models/design_summary.dart';
import 'core_model_state.dart';

class CoreModelController extends ChangeNotifier {
  CoreModelController({
    required String routeId,
    required CoreCalculationRepository calculationRepository,
    required CoreDesignRepository designRepository,
  }) : _routeId = routeId,
       _calculationRepository = calculationRepository,
       _designRepository = designRepository,
       _state = CoreModelState.initial(routeId: routeId);

  final String _routeId;
  final CoreCalculationRepository _calculationRepository;
  final CoreDesignRepository _designRepository;

  CoreModelState _state;

  CoreModelState get state => _state;

  Future<void> initialize({DesignSummary? initialSummary}) async {
    if (_state.isInitialized) {
      return;
    }

    final twoWindingDesign = _readTwoWindingDesign(initialSummary?.twoWindings);
    final coreResult = _readCoreResult(initialSummary?.core);
    final request = _buildInitialRequest(
      twoWindingDesign: twoWindingDesign,
      coreResult: coreResult,
    );
    final selection = _selectionFromResult(coreResult);

    _setState(
      _state.copyWith(
        isInitialized: true,
        entityId: initialSummary?.id ?? (_routeId == 'new' ? '' : _routeId),
        designId:
            initialSummary?.designId ??
            twoWindingDesign?.stringAt('designId') ??
            '',
        twoWindingDesign: twoWindingDesign,
        request: request,
        result: coreResult,
        selectedStepNo: selection.stepNo,
        editedWidth: selection.width,
        editedStack: selection.stack,
        errorMessage: '',
      ),
    );

    if (_shouldAutoCalculate()) {
      await calculate();
    }
  }

  void setMinimumStepWidth(String value) {
    _setState(
      _state.copyWith(
        request: _state.request.copyWith(minimumStepWidth: value),
        errorMessage: '',
      ),
    );
  }

  void setNumberOfSteps(String value) {
    _setState(
      _state.copyWith(
        request: _state.request.copyWith(numberOfSteps: value),
        errorMessage: '',
      ),
    );
  }

  void setFixtureStepWidth(String value) {
    _setState(
      _state.copyWith(
        request: _state.request.copyWith(
          fixtureStepWidth: value.trim().isEmpty ? null : value,
        ),
        errorMessage: '',
      ),
    );
  }

  void setBladeType(String value) {
    _setState(
      _state.copyWith(
        request: _state.request.copyWith(eCoreBladeType: value),
        errorMessage: '',
      ),
    );
  }

  void selectStep(Object? stepNo) {
    final step = _findSelectedStep(stepNo);
    if (step == null) {
      return;
    }

    _setState(
      _state.copyWith(
        selectedStepNo: step.stepNo,
        editedWidth: _stringify(step.width),
        editedStack: _stringify(step.stack),
      ),
    );
  }

  void updateEditedWidth(String value) {
    _setState(_state.copyWith(editedWidth: value, editedStack: ''));
  }

  void updateEditedStack(String value) {
    _setState(_state.copyWith(editedStack: value));
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }

    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<bool> calculate() async {
    if (_state.isLoading) {
      return false;
    }

    if (!_state.hasDesignContext) {
      _setState(
        _state.copyWith(
          errorMessage:
              'Open the core model from a saved two-winding design before calculating.',
        ),
      );
      return false;
    }

    return _runCalculation(_state.request);
  }

  Future<bool> saveSelectedStep() async {
    if (_state.isLoading) {
      return false;
    }

    final selectedStepNo = _state.selectedStepNo;
    final result = _state.result;
    if (selectedStepNo == null || result == null) {
      return false;
    }

    final previousRows = result.bldStacks
        .where((row) => _compareStepNo(row.stepNo, selectedStepNo) < 0)
        .map(
          (row) => CoreStackRequestEntry(
            stepNo: row.stepNo,
            width: row.width,
            stack: row.stack,
          ),
        )
        .toList(growable: false);
    final request = _state.request.copyWith(
      prevCoreStackRequestList: previousRows,
      coreStackRequestList: <CoreStackRequestEntry>[
        CoreStackRequestEntry(
          stepNo: selectedStepNo,
          width: _state.editedWidth,
          stack: _state.editedStack,
        ),
      ],
    );

    return _runCalculation(request);
  }

  String displayValue(Object? value, {String fallback = '-'}) {
    final text = _stringify(value).trim();
    return text.isEmpty ? fallback : text;
  }

  String revisedFluxDensityText() {
    return _state.twoWindingDesign?.stringAt('lvFormulas.revisedFluxDensity') ??
        '';
  }

  Future<bool> _runCalculation(CoreCalculationRequest request) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: ''));

    try {
      final result = await _calculationRepository.calculate(request);
      await _designRepository.persistCore(
        entityId: _state.entityId,
        core: result,
      );

      final normalizedRequest = _normalizeRequestFromResult(
        current: request,
        result: result,
      );
      final selection = _selectionFromResult(
        result,
        preferredStepNo: _state.selectedStepNo,
      );

      _setState(
        _state.copyWith(
          isLoading: false,
          request: normalizedRequest,
          result: result,
          selectedStepNo: selection.stepNo,
          editedWidth: selection.width,
          editedStack: selection.stack,
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
          errorMessage: 'Unable to calculate the core model.',
        ),
      );
      return false;
    }
  }

  bool _shouldAutoCalculate() {
    final request = _state.request;
    if (!_state.hasDesignContext || _state.result?.coreArea != null) {
      return false;
    }

    final coreDiameter = request.coreDiameter;
    if (coreDiameter == null) {
      return false;
    }

    final rawValue = _stringify(coreDiameter);
    if (rawValue.isEmpty) {
      return false;
    }

    final asNumber = double.tryParse(rawValue);
    return asNumber == null ? rawValue != '0' : asNumber != 0;
  }

  TwoWindingDesign? _readTwoWindingDesign(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : TwoWindingDesign.fromJson(json);
  }

  CoreCalculationResult? _readCoreResult(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : CoreCalculationResult.fromJson(json);
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

  CoreCalculationRequest _buildInitialRequest({
    required TwoWindingDesign? twoWindingDesign,
    required CoreCalculationResult? coreResult,
  }) {
    final request = CoreCalculationRequest.initial(
      coreDiameter: twoWindingDesign?.readPath('core.coreDia'),
      limbHt: twoWindingDesign?.readPath('core.limbHt'),
      cenDist: twoWindingDesign?.readPath('core.cenDist'),
    );

    if (coreResult == null || coreResult.coreArea == null) {
      return request;
    }

    final steps = coreResult.bldStacks;
    if (steps.isEmpty) {
      return request;
    }

    final last = steps.last;
    return request.copyWith(
      minimumStepWidth: last.width ?? 0,
      numberOfSteps: steps.length,
    );
  }

  CoreCalculationRequest _normalizeRequestFromResult({
    required CoreCalculationRequest current,
    required CoreCalculationResult result,
  }) {
    final steps = result.bldStacks;
    if (steps.isEmpty) {
      return current.copyWith(
        coreStackRequestList: const <CoreStackRequestEntry>[],
        prevCoreStackRequestList: const <CoreStackRequestEntry>[],
      );
    }

    return current.copyWith(
      coreDiameter:
          _state.twoWindingDesign?.readPath('core.coreDia') ??
          current.coreDiameter,
      minimumStepWidth: steps.last.width ?? current.minimumStepWidth,
      numberOfSteps: steps.length,
      coreStackRequestList: const <CoreStackRequestEntry>[],
      prevCoreStackRequestList: const <CoreStackRequestEntry>[],
    );
  }

  _StepSelection _selectionFromResult(
    CoreCalculationResult? result, {
    Object? preferredStepNo,
  }) {
    final steps = result?.bldStacks ?? const <CoreStackStep>[];
    if (steps.isEmpty) {
      return const _StepSelection(stepNo: null, width: '', stack: '');
    }

    final selected = preferredStepNo == null
        ? steps.first
        : steps.firstWhere(
            (step) => _sameValue(step.stepNo, preferredStepNo),
            orElse: () => steps.first,
          );

    return _StepSelection(
      stepNo: selected.stepNo,
      width: _stringify(selected.width),
      stack: _stringify(selected.stack),
    );
  }

  CoreStackStep? _findSelectedStep(Object? stepNo) {
    for (final step in _state.result?.bldStacks ?? const <CoreStackStep>[]) {
      if (_sameValue(step.stepNo, stepNo)) {
        return step;
      }
    }
    return null;
  }

  int _compareStepNo(Object? left, Object? right) {
    final leftNum = double.tryParse(_stringify(left));
    final rightNum = double.tryParse(_stringify(right));
    if (leftNum != null && rightNum != null) {
      return leftNum.compareTo(rightNum);
    }

    return _stringify(left).compareTo(_stringify(right));
  }

  bool _sameValue(Object? left, Object? right) {
    return _stringify(left) == _stringify(right);
  }

  String _stringify(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  void _setState(CoreModelState nextState) {
    _state = nextState;
    notifyListeners();
  }
}

class _StepSelection {
  const _StepSelection({
    required this.stepNo,
    required this.width,
    required this.stack,
  });

  final Object? stepNo;
  final String width;
  final String stack;
}
