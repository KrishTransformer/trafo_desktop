import 'package:flutter/foundation.dart';

import '../../files/domain/models/lom_material_entry.dart';

@immutable
class LomCostState {
  const LomCostState({
    required this.isInitialized,
    required this.isLoading,
    required this.isSaving,
    required this.isApplyingDefaults,
    required this.materials,
    required this.errorMessage,
  });

  const LomCostState.initial()
    : isInitialized = false,
      isLoading = false,
      isSaving = false,
      isApplyingDefaults = false,
      materials = const <LomMaterialEntry>[],
      errorMessage = '';

  final bool isInitialized;
  final bool isLoading;
  final bool isSaving;
  final bool isApplyingDefaults;
  final List<LomMaterialEntry> materials;
  final String errorMessage;

  bool get isBusy => isLoading || isSaving || isApplyingDefaults;

  LomCostState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isSaving,
    bool? isApplyingDefaults,
    List<LomMaterialEntry>? materials,
    String? errorMessage,
  }) {
    return LomCostState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isApplyingDefaults: isApplyingDefaults ?? this.isApplyingDefaults,
      materials: materials ?? this.materials,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
