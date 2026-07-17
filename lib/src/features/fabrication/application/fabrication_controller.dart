import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../home/domain/models/design_summary.dart';
import '../domain/models/cad_generation_request.dart';
import '../domain/models/drawings_status_create_request.dart';
import '../domain/models/fabrication_calculation_request.dart';
import '../domain/models/fabrication_calculation_result.dart';
import '../domain/models/fabrication_defaults.dart';
import '../domain/repositories/drawings_status_repository.dart';
import '../domain/repositories/fabrication_cad_repository.dart';
import '../domain/repositories/fabrication_calculation_repository.dart';
import '../domain/repositories/fabrication_design_repository.dart';
import 'fabrication_state.dart';

class FabricationController extends ChangeNotifier {
  FabricationController({
    required String routeId,
    required FabricationCalculationRepository calculationRepository,
    required FabricationDesignRepository designRepository,
    required FabricationCadRepository cadRepository,
    required DrawingsStatusRepository drawingsStatusRepository,
  }) : _routeId = routeId,
       _calculationRepository = calculationRepository,
       _designRepository = designRepository,
       _cadRepository = cadRepository,
       _drawingsStatusRepository = drawingsStatusRepository,
       _state = FabricationState.initial(routeId: routeId);

  final String _routeId;
  final FabricationCalculationRepository _calculationRepository;
  final FabricationDesignRepository _designRepository;
  final FabricationCadRepository _cadRepository;
  final DrawingsStatusRepository _drawingsStatusRepository;

  FabricationState _state;

  FabricationState get state => _state;

  Future<void> initialize({DesignSummary? initialSummary}) async {
    if (_state.isInitialized) {
      return;
    }

    final twoWindingDesign = _readTwoWindingDesign(initialSummary?.twoWindings);
    final coreResult = _readCoreResult(initialSummary?.core);
    final persistedFabrication = _readFabrication(initialSummary?.fabrication);
    final seededFormData = _buildSeededFormData(
      twoWindingDesign: twoWindingDesign,
      coreResult: coreResult,
    );
    final resolvedDesignId =
        initialSummary?.designId ??
        twoWindingDesign?.stringAt('designId') ??
        '';
    final entityId = initialSummary?.id ?? (_routeId == 'new' ? '' : _routeId);
    final shouldUsePersisted = _hasPersistedFabrication(persistedFabrication);

    _setState(
      _state.copyWith(
        isInitialized: true,
        entityId: entityId,
        designId: resolvedDesignId,
        twoWindingDesign: twoWindingDesign,
        coreResult: coreResult,
        formData: shouldUsePersisted ? persistedFabrication! : seededFormData,
        result: shouldUsePersisted ? persistedFabrication : null,
        errorMessage: '',
      ),
    );

    await refreshStatuses(silent: true);
    await loadCadModel(silent: true);

    if (_shouldAutoCalculate(persistedFabrication)) {
      await calculate();
    }
  }

  void updateField(String path, Object? value) {
    var nextFormData = _state.formData.copyWithPath(path, value);

    switch (path) {
      case 'gorPipe.buchholz_Relay':
        nextFormData = nextFormData
            .copyWithPath('gorPipe.single_Valve', true)
            .copyWithPath('gorPipe.valve_Type1', true);
        break;
      case 'hvcb.hvcb':
        nextFormData = nextFormData.copyWithPath(
          'hvb.hvb_Pos',
          _toBool(value) ? 'tank' : 'lid',
        );
        break;
      case 'lvcb.lvcb':
        nextFormData = nextFormData.copyWithPath(
          'lvb.lvb_Pos',
          _toBool(value) ? 'tank' : 'lid',
        );
        break;
    }

    _setState(
      _state.copyWith(
        formData: nextFormData,
        hasEditedSinceLastGenerate: true,
        errorMessage: '',
      ),
    );
  }

  void openStatusDrawer() {
    if (_state.isStatusDrawerOpen) {
      return;
    }
    _setState(_state.copyWith(isStatusDrawerOpen: true));
  }

  void closeStatusDrawer() {
    if (!_state.isStatusDrawerOpen) {
      return;
    }
    _setState(_state.copyWith(isStatusDrawerOpen: false));
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
              'Open fabrication from a saved two-winding design before calculating.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isLoading: true, errorMessage: ''));

    try {
      final request = FabricationCalculationRequest.fromJson(
        _buildCalculatePayload(),
      );
      final result = await _calculationRepository.calculate(request);
      await _designRepository.persistFabrication(
        entityId: _state.entityId,
        fabrication: result,
      );

      _setState(
        _state.copyWith(
          isLoading: false,
          formData: result,
          result: result,
          hasCalculatedSinceLastGenerate: true,
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
          errorMessage: 'Unable to calculate fabrication.',
        ),
      );
      return false;
    }
  }

  Future<bool> generate3D() async {
    if (_state.isGenerating3D) {
      return false;
    }

    final designId = _state.formData.stringAt(
      'restOfVariables.designId',
      fallback: _state.designId,
    );
    if (designId.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'Fabrication design reference is missing.',
        ),
      );
      return false;
    }

    _setState(
      _state.copyWith(
        isGenerating3D: true,
        hasCalculatedSinceLastGenerate: false,
        hasEditedSinceLastGenerate: false,
        errorMessage: '',
      ),
    );

    try {
      final matchingStatuses = _state.drawingsStatuses
          .where((entry) => entry.designId == designId)
          .toList(growable: false);
      for (final entry in matchingStatuses) {
        await _drawingsStatusRepository.deleteStatus(entry.id);
      }

      final response = await _cadRepository.generate3D(
        CadGenerationRequest(
          payload: _buildGenerate3DPayload(),
          fileName: designId,
        ),
      );

      if (response.message.toLowerCase().contains('fabrication')) {
        await _drawingsStatusRepository.createStatus(
          DrawingsStatusCreateRequest(
            designId: designId,
            message: 'Generate 3D Requested',
            status: 'Success',
          ),
        );
      }

      await refreshStatuses(silent: true);
      _setState(
        _state.copyWith(
          isGenerating3D: false,
          cadGenerationMessage: response.message,
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isGenerating3D: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isGenerating3D: false,
          errorMessage: 'Unable to start fabrication 3D generation.',
        ),
      );
      return false;
    }
  }

  Future<void> refreshStatuses({bool silent = false}) async {
    final designId = _state.designId;
    if (designId.isEmpty) {
      return;
    }

    if (!silent) {
      _setState(_state.copyWith(isRefreshingStatuses: true, errorMessage: ''));
    }

    try {
      final response = await _drawingsStatusRepository.fetchStatuses(
        designId: designId,
      );
      _setState(
        _state.copyWith(
          isRefreshingStatuses: false,
          drawingsStatuses: response.data,
        ),
      );

      if (_state.hasCompletedCadStatus && !_state.hasCadModel) {
        await loadCadModel(silent: true);
      }
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isRefreshingStatuses: false,
          errorMessage: silent ? _state.errorMessage : exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isRefreshingStatuses: false,
          errorMessage: silent
              ? _state.errorMessage
              : 'Unable to refresh CAD status.',
        ),
      );
    }
  }

  Future<void> loadCadModel({bool silent = false}) async {
    final designId = _state.designId;
    if (designId.isEmpty) {
      return;
    }

    if (!silent) {
      _setState(_state.copyWith(isLoadingCadModel: true, errorMessage: ''));
    }

    try {
      final model = await _cadRepository.loadModel(designId);
      _setState(_state.copyWith(isLoadingCadModel: false, cadModel: model));
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isLoadingCadModel: false,
          errorMessage: silent ? _state.errorMessage : exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoadingCadModel: false,
          errorMessage: silent
              ? _state.errorMessage
              : 'Unable to load the 3D model.',
        ),
      );
    }
  }

  FabricationCalculationResult _buildSeededFormData({
    required TwoWindingDesign? twoWindingDesign,
    required CoreCalculationResult? coreResult,
  }) {
    var formData = FabricationCalculationResult.fromJson(
      kFabricationDefaultJson,
    );
    final radiatorCount = _toDouble(
      twoWindingDesign?.readPath('tankAndOilFormulas.noOfRadiators'),
    );
    final halfRadiatorCount = radiatorCount == null ? null : radiatorCount / 2;
    final limbNos =
        coreResult?.readPath('numberOfSteps') ?? coreResult?.bldStacks.length;

    formData = formData
        .copyWithPath(
          'restOfVariables.designId',
          twoWindingDesign?.readPath('designId'),
        )
        .copyWithPath('restOfVariables.kVA', twoWindingDesign?.readPath('kVA'))
        .copyWithPath(
          'restOfVariables.transformer_Weight',
          twoWindingDesign?.readPath('tankAndOilFormulas.transformerWeight'),
        )
        .copyWithPath(
          'restOfVariables.limb_CC',
          twoWindingDesign?.readPath('core.cenDist'),
        )
        .copyWithPath('restOfVariables.limb_Nos', limbNos)
        .copyWithPath(
          'restOfVariables.limb_H',
          twoWindingDesign?.readPath('core.limbHt'),
        )
        .copyWithPath(
          'tank.tank_L',
          twoWindingDesign?.readPath('tank.tankLength'),
        )
        .copyWithPath(
          'tank.tank_W',
          twoWindingDesign?.readPath('tank.tankWidth'),
        )
        .copyWithPath(
          'tank.tank_H',
          twoWindingDesign?.readPath('tank.tankHeight'),
        )
        .copyWithPath(
          'tank.tank_Thick',
          twoWindingDesign?.readPath('tank.tankWallThickness'),
        )
        .copyWithPath(
          'tank.tank_Bot_Thick',
          twoWindingDesign?.readPath('tank.tankBottomThickness'),
        )
        .copyWithPath(
          'tank.tank_Flg_Thick',
          twoWindingDesign?.readPath('tank.frameThickness'),
        )
        .copyWithPath(
          'radiator.radiator_CC',
          twoWindingDesign?.readPath('tankAndOilFormulas.radiatorHeight'),
        )
        .copyWithPath(
          'radiator.radiator_W',
          twoWindingDesign?.readPath('tankAndOilFormulas.radiatorWidth'),
        )
        .copyWithPath(
          'radiator.radiator_Fin_Nos',
          twoWindingDesign?.readPath('tankAndOilFormulas.noOfFinsPerRadiator'),
        )
        .copyWithPath(
          'radiator.radiator_Nos',
          twoWindingDesign?.readPath('tankAndOilFormulas.noOfRadiators'),
        )
        .copyWithPath('radiator.radiator_Left_Nos', halfRadiatorCount)
        .copyWithPath('radiator.radiator_Right_Nos', halfRadiatorCount)
        .copyWithPath(
          'lid.lid_Thick',
          twoWindingDesign?.readPath('tank.tankLidThickness'),
        )
        .copyWithPath('hvb.hvb_Volt', twoWindingDesign?.readPath('highVoltage'))
        .copyWithPath(
          'hvb.hvb_Amp',
          twoWindingDesign?.readPath('tankAndOilFormulas.hvBushingCurrent'),
        )
        .copyWithPath('lvb.lvb_Volt', twoWindingDesign?.readPath('lowVoltage'))
        .copyWithPath(
          'lvb.lvb_Amp',
          twoWindingDesign?.readPath('tankAndOilFormulas.lvBushingCurrent'),
        )
        .copyWithPath(
          'cons.cons_Vol',
          twoWindingDesign?.readPath('tankAndOilFormulas.conservatorCapacity'),
        )
        .copyWithPath(
          'cons.cons_Dia',
          twoWindingDesign?.readPath('tankAndOilFormulas.conservatorDia'),
        )
        .copyWithPath(
          'cons.cons_L',
          twoWindingDesign?.readPath('tankAndOilFormulas.conservatorLength'),
        )
        .copyWithPath(
          'fabricationCore.core_Dia',
          twoWindingDesign?.readPath('core.coreDia'),
        )
        .copyWithPath(
          'lv.lv_ID',
          twoWindingDesign?.readPath('coilDimensions.lvid'),
        )
        .copyWithPath(
          'lv.lv_OD',
          twoWindingDesign?.readPath('coilDimensions.lvod'),
        )
        .copyWithPath(
          'lv.lv_Wdg_L',
          twoWindingDesign?.readPath('innerWindings.windingLength'),
        )
        .copyWithPath(
          'lv.lv_Volts',
          twoWindingDesign?.readPath('innerWindings.turnsPerPhase'),
        )
        .copyWithPath(
          'hv.hv_ID',
          twoWindingDesign?.readPath('coilDimensions.hvid'),
        )
        .copyWithPath(
          'hv.hv_OD',
          twoWindingDesign?.readPath('coilDimensions.hvod'),
        )
        .copyWithPath(
          'hv.hv_Wdg_L',
          twoWindingDesign?.readPath('outerWindings.windingLength'),
        );

    return formData;
  }

  bool _shouldAutoCalculate(
    FabricationCalculationResult? persistedFabrication,
  ) {
    if (!_state.hasDesignContext) {
      return false;
    }

    final tankLength = persistedFabrication?.stringAt('tank.tank_L') ?? '';
    return tankLength.isEmpty;
  }

  bool _hasPersistedFabrication(FabricationCalculationResult? fabrication) {
    if (fabrication == null) {
      return false;
    }
    return fabrication.stringAt('restOfVariables.designId').isNotEmpty;
  }

  TwoWindingDesign? _readTwoWindingDesign(Object? raw) {
    final json = _readJsonMap(raw);
    return json == null ? null : TwoWindingDesign.fromJson(json);
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

  Map<String, dynamic> _buildCalculatePayload() {
    final twoWinding = _state.twoWindingDesign;
    final formData = _state.formData;
    final tapStepPercent =
        _toDouble(twoWinding?.readPath('tapStepsPercent')) ?? 0;
    final tapStepsPositive =
        _toDouble(twoWinding?.readPath('tapStepsPositive')) ?? 0;
    final tapStepsNegative =
        _toDouble(twoWinding?.readPath('tapStepsNegative')) ?? 0;
    final hvCurrentPerPhase =
        _toDouble(twoWinding?.readPath('hvFormulas.hvCurrentPerPhase')) ?? 0;

    return <String, dynamic>{
      'designId': twoWinding?.readPath('designId'),
      'kVA': twoWinding?.readPath('kVA'),
      'transformer_Weight': twoWinding?.readPath(
        'tankAndOilFormulas.transformerWeight',
      ),
      'limb_CC': twoWinding?.readPath('core.cenDist'),
      'limb_Nos': 3,
      'limb_H': twoWinding?.readPath('core.limbHt'),
      'tank_L': twoWinding?.readPath('tank.tankLength'),
      'tank_W': twoWinding?.readPath('tank.tankWidth'),
      'tank_H': twoWinding?.readPath('tank.tankHeight'),
      'tank_Thick': twoWinding?.readPath('tank.tankWallThickness'),
      'tank_Bot_Thick': twoWinding?.readPath('tank.tankBottomThickness'),
      'tank_Flg_Thick': twoWinding?.readPath('tank.frameThickness'),
      'radiator_CC': twoWinding?.readPath('tankAndOilFormulas.radiatorHeight'),
      'radiator_W': twoWinding?.readPath('tankAndOilFormulas.radiatorWidth'),
      'radiator_Fin_Nos': twoWinding?.readPath(
        'tankAndOilFormulas.noOfFinsPerRadiator',
      ),
      'radiator_Nos': twoWinding?.readPath('tankAndOilFormulas.noOfRadiators'),
      'radiator_Left_Nos': _halfValue(
        twoWinding?.readPath('tankAndOilFormulas.noOfRadiators'),
      ),
      'radiator_Right_Nos': _halfValue(
        twoWinding?.readPath('tankAndOilFormulas.noOfRadiators'),
      ),
      'lid_Thick': twoWinding?.readPath('tank.tankLidThickness'),
      'hvb_Volt': formData.readPath('hvb.hvb_Volt'),
      'hvb_Amp': formData.readPath('hvb.hvb_Amp'),
      'lvb_Volt': formData.readPath('lvb.lvb_Volt'),
      'lvb_Amp': formData.readPath('lvb.lvb_Amp'),
      'cons_Vol': twoWinding?.readPath(
        'tankAndOilFormulas.conservatorCapacity',
      ),
      'cons_Dia': twoWinding?.readPath('tankAndOilFormulas.conservatorDia'),
      'cons_L': twoWinding?.readPath('tankAndOilFormulas.conservatorLength'),
      'core_Dia': twoWinding?.readPath('core.coreDia'),
      'lv_ID': twoWinding?.readPath('coilDimensions.lvid'),
      'lv_OD': twoWinding?.readPath('coilDimensions.lvod'),
      'lv_Wdg_L': twoWinding?.readPath('innerWindings.windingLength'),
      'lv_Volts': twoWinding?.readPath('innerWindings.turnsPerPhase'),
      'hv_ID': twoWinding?.readPath('coilDimensions.hvid'),
      'hv_OD': twoWinding?.readPath('coilDimensions.hvod'),
      'hv_Wdg_L': twoWinding?.readPath('outerWindings.windingLength'),
      'hvb_Pos': formData.readPath('hvb.hvb_Pos'),
      'lvb_Pos': formData.readPath('lvb.lvb_Pos'),
      'hvcb': formData.readPath('hvcb.hvcb'),
      'lvcb': formData.readPath('lvcb.lvcb'),
      'drain_Vlv': formData.readPath('drain_Vlv.drain_Vlv'),
      'drain_Vlv_Nos': formData.readPath('drain_Vlv.drain_Vlv_Nos'),
      'smpl_Vlv': formData.readPath('smpl_Vlv.smpl_Vlv'),
      'smpl_Vlv_Nos': formData.readPath('smpl_Vlv.smpl_Vlv_Nos'),
      'fill_Vlv': formData.readPath('fill_Vlv.fill_Vlv'),
      'roller': formData.readPath('roller.roller'),
      'roller_Type': formData.readPath('roller.roller_Type'),
      'mog': formData.readPath('mog.mog'),
      'buchholz_Relay': formData.readPath('gorPipe.buchholz_Relay'),
      'single_Valve': formData.readPath('gorPipe.single_Valve'),
      'valve_Type1': formData.readPath('gorPipe.valve_Type1'),
      'mog_Tlt_Ang': formData.readPath('mog.mog_Tlt_Ang'),
      'prv': formData.readPath('restOfVariables.prv'),
      'exp_Vent': formData.readPath('exp_Vent.exp_Vent'),
      'exp_Vent_ID': formData.readPath('exp_Vent.exp_Vent_ID'),
      'radiator_Vlv': formData.readPath('radiator.radiator_Vlv'),
      'lid_LiftLug': formData.readPath('lid_LiftLug.lid_LiftLug'),
      'lid_LiftLug_Thick': formData.readPath('lid_LiftLug.lid_LiftLug_Thick'),
      'mbox': formData.readPath('restOfVariables.mbox'),
      'mbox_Inst_Nos': formData.readPath('restOfVariables.mbox_Inst_Nos'),
      'thrmo_Syphn': formData.readPath('restOfVariables.thrmo_Syphn'),
      'roller_Guage': formData.readPath('roller.roller_Guage'),
      'thermoPkt1': formData.readPath('thermoPkt.thermoPkt1'),
      'thermoPkt2': formData.readPath('thermoPkt.thermoPkt2'),
      'exp_Vent_With_OI': formData.readPath('exp_Vent.exp_Vent_With_OI'),
      'isRoller': formData.readPath('bot_Chnl.isRoller'),
      'eVectorGroup': twoWinding?.readPath('vectorGroup'),
      'printouts': <String, dynamic>{
        'kva': twoWinding?.readPath('kVA'),
        'voltsAtHv': twoWinding?.readPath('highVoltage'),
        'voltsAtLv': twoWinding?.readPath('lowVoltage'),
        'amperesHv': twoWinding?.readPath('hvFormulas.hvCurrentPerPhase'),
        'amperesLv': twoWinding?.readPath('lvFormulas.lvCurrentPerPhase'),
        'phasesHv': _phaseLabel(twoWinding?.stringAt('vectorGroup'), 0, 'D'),
        'phasesLv': _phaseLabel(twoWinding?.stringAt('vectorGroup'), 1, 'd'),
        'frequency': twoWinding?.readPath('frequency'),
        'impedance': twoWinding?.readPath('commonFormulas.ek'),
        'vectorGroup': twoWinding?.readPath('vectorGroup'),
        'topOilTemp': twoWinding?.readPath('topOilTemp'),
        'windingTemp': twoWinding?.readPath('windingTemp'),
        'coolingType': 'ONAN',
        'weightsOfActivePart': twoWinding?.readPath(
          'tankAndOilFormulas.weightsOfActivePart',
        ),
        'oilWeight': twoWinding?.readPath('tankAndOilFormulas.oilWeight'),
        'totalOil': twoWinding?.readPath('tankAndOilFormulas.totalOil'),
        'basicInsulationLevelHV': _insulationLevel(
          impulse: twoWinding?.readPath('hvImpulseVoltage'),
          test: twoWinding?.readPath('hvTestVoltage'),
        ),
        'basicInsulationLevelLV': _insulationLevel(
          impulse: twoWinding?.readPath('lvImpulseVoltage'),
          test: twoWinding?.readPath('lvTestVoltage'),
        ),
        'ampsHV': (hvCurrentPerPhase * 1.7320508075688772 * 100).round() / 100,
        'ampsLV': twoWinding?.readPath('lvFormulas.lvCurrentPerPhase'),
        'tappingHVVariations':
            '+${tapStepPercent * tapStepsPositive}% to -${tapStepPercent * tapStepsNegative}% @$tapStepPercent%',
        'lossesAt50': twoWinding?.readPath('lossesAt50Percent'),
        'lossesAt100': twoWinding?.readPath('lossesAt100Percent'),
        'weightOfTankAndAcc': twoWinding?.readPath(
          'tankAndOilFormulas.weightOfTankAndAcc',
        ),
      },
      'turnsPerTap': twoWinding?.readPath('hvFormulas.turnsPerTap'),
      'tapVoltages': twoWinding?.readPath('hvFormulas.tapVoltages'),
      'tapCurrent': twoWinding?.readPath('hvFormulas.tapCurrent'),
      'tapStepPercentage': twoWinding?.readPath('tapStepsPercent'),
      'isOCTC': tapStepPercent > 0,
    };
  }

  Map<String, dynamic> _buildGenerate3DPayload() {
    final payload = <String, dynamic>{};

    for (final entry in _state.formData.toJson().entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        payload.addAll(value);
      } else if (value is Map<Object?, Object?>) {
        payload.addAll(Map<String, dynamic>.from(value));
      } else {
        payload[entry.key] = value;
      }
    }

    return payload;
  }

  String _phaseLabel(String? vectorGroup, int index, String deltaChar) {
    if (vectorGroup == null || vectorGroup.length <= index) {
      return 'Star';
    }
    return vectorGroup[index] == deltaChar ? 'Delta' : 'Star';
  }

  String _insulationLevel({required Object? impulse, required Object? test}) {
    final impulseValue = _toDouble(impulse) ?? 0;
    final testValue = _toDouble(test) ?? 0;
    final impulseText = impulseValue == 0 ? '-' : '${_display(impulse)}KVp';
    final testText = testValue == 0 ? '-' : '${_display(test)}KV';
    return '$impulseText / $testText';
  }

  Object? _halfValue(Object? value) {
    final asNumber = _toDouble(value);
    if (asNumber == null) {
      return value;
    }
    return asNumber / 2;
  }

  bool _toBool(Object? value) {
    return switch (value) {
      true => true,
      'true' => true,
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

  String _display(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  void _setState(FabricationState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
