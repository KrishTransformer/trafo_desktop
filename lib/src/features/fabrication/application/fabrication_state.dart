import 'package:flutter/foundation.dart';

import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../domain/models/drawings_status_entry.dart';
import '../domain/models/fabrication_calculation_result.dart';
import '../domain/models/fabrication_defaults.dart';
import '../domain/models/stored_cad_model.dart';

enum FabricationCadAction { generate3d, showStatus }

@immutable
class FabricationState {
  const FabricationState({
    required this.isInitialized,
    required this.isLoading,
    required this.isGenerating3D,
    required this.isRefreshingStatuses,
    required this.isLoadingCadModel,
    required this.isStatusDrawerOpen,
    required this.routeId,
    required this.entityId,
    required this.designId,
    required this.twoWindingDesign,
    required this.coreResult,
    required this.formData,
    required this.result,
    required this.drawingsStatuses,
    required this.cadModel,
    required this.cadGenerationMessage,
    required this.hasCalculatedSinceLastGenerate,
    required this.hasEditedSinceLastGenerate,
    required this.errorMessage,
  });

  factory FabricationState.initial({required String routeId}) {
    return FabricationState(
      isInitialized: false,
      isLoading: false,
      isGenerating3D: false,
      isRefreshingStatuses: false,
      isLoadingCadModel: false,
      isStatusDrawerOpen: false,
      routeId: routeId,
      entityId: '',
      designId: '',
      twoWindingDesign: null,
      coreResult: null,
      formData: FabricationCalculationResult.fromJson(kFabricationDefaultJson),
      result: null,
      drawingsStatuses: const <DrawingsStatusEntry>[],
      cadModel: null,
      cadGenerationMessage: '',
      hasCalculatedSinceLastGenerate: false,
      hasEditedSinceLastGenerate: false,
      errorMessage: '',
    );
  }

  final bool isInitialized;
  final bool isLoading;
  final bool isGenerating3D;
  final bool isRefreshingStatuses;
  final bool isLoadingCadModel;
  final bool isStatusDrawerOpen;
  final String routeId;
  final String entityId;
  final String designId;
  final TwoWindingDesign? twoWindingDesign;
  final CoreCalculationResult? coreResult;
  final FabricationCalculationResult formData;
  final FabricationCalculationResult? result;
  final List<DrawingsStatusEntry> drawingsStatuses;
  final StoredCadModel? cadModel;
  final String cadGenerationMessage;
  final bool hasCalculatedSinceLastGenerate;
  final bool hasEditedSinceLastGenerate;
  final String errorMessage;

  bool get isBusy =>
      isLoading || isGenerating3D || isRefreshingStatuses || isLoadingCadModel;

  bool get hasDesignContext => twoWindingDesign != null && entityId.isNotEmpty;

  bool get hasCadModel => cadModel != null && cadModel!.bytes.isNotEmpty;

  DrawingsStatusEntry? get latestStatus {
    if (drawingsStatuses.isEmpty) {
      return null;
    }
    return drawingsStatuses.last;
  }

  bool get hasCompletedCadStatus =>
      latestStatus?.message.contains('Process finished!') ?? false;

  bool get isStatusWindowExpired {
    if (drawingsStatuses.isEmpty) {
      return false;
    }

    final oldest = DateTime.tryParse(drawingsStatuses.first.createdAt ?? '');
    if (oldest == null) {
      return false;
    }

    return DateTime.now().difference(oldest) > const Duration(minutes: 45);
  }

  bool get shouldShowStatusButton {
    return !isGenerating3D &&
        drawingsStatuses.isNotEmpty &&
        !hasCompletedCadStatus &&
        !isStatusWindowExpired;
  }

  bool get canGenerate3D {
    final isDirty =
        hasCalculatedSinceLastGenerate && hasEditedSinceLastGenerate;
    final noTrackedStatuses = drawingsStatuses.isEmpty;

    return (isDirty || noTrackedStatuses || isStatusWindowExpired) &&
        (hasCadModel || isDirty || isStatusWindowExpired || noTrackedStatuses);
  }

  FabricationCadAction get cadPrimaryAction {
    return shouldShowStatusButton
        ? FabricationCadAction.showStatus
        : FabricationCadAction.generate3d;
  }

  FabricationState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isGenerating3D,
    bool? isRefreshingStatuses,
    bool? isLoadingCadModel,
    bool? isStatusDrawerOpen,
    String? routeId,
    String? entityId,
    String? designId,
    TwoWindingDesign? twoWindingDesign,
    bool clearTwoWindingDesign = false,
    CoreCalculationResult? coreResult,
    bool clearCoreResult = false,
    FabricationCalculationResult? formData,
    FabricationCalculationResult? result,
    bool clearResult = false,
    List<DrawingsStatusEntry>? drawingsStatuses,
    StoredCadModel? cadModel,
    bool clearCadModel = false,
    String? cadGenerationMessage,
    bool? hasCalculatedSinceLastGenerate,
    bool? hasEditedSinceLastGenerate,
    String? errorMessage,
  }) {
    return FabricationState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isGenerating3D: isGenerating3D ?? this.isGenerating3D,
      isRefreshingStatuses: isRefreshingStatuses ?? this.isRefreshingStatuses,
      isLoadingCadModel: isLoadingCadModel ?? this.isLoadingCadModel,
      isStatusDrawerOpen: isStatusDrawerOpen ?? this.isStatusDrawerOpen,
      routeId: routeId ?? this.routeId,
      entityId: entityId ?? this.entityId,
      designId: designId ?? this.designId,
      twoWindingDesign: clearTwoWindingDesign
          ? null
          : twoWindingDesign ?? this.twoWindingDesign,
      coreResult: clearCoreResult ? null : coreResult ?? this.coreResult,
      formData: formData ?? this.formData,
      result: clearResult ? null : result ?? this.result,
      drawingsStatuses: drawingsStatuses ?? this.drawingsStatuses,
      cadModel: clearCadModel ? null : cadModel ?? this.cadModel,
      cadGenerationMessage: cadGenerationMessage ?? this.cadGenerationMessage,
      hasCalculatedSinceLastGenerate:
          hasCalculatedSinceLastGenerate ?? this.hasCalculatedSinceLastGenerate,
      hasEditedSinceLastGenerate:
          hasEditedSinceLastGenerate ?? this.hasEditedSinceLastGenerate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
