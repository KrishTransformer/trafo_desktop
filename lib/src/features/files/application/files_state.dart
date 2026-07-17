import 'package:flutter/foundation.dart';

import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../fabrication/domain/models/fabrication_calculation_result.dart';
import '../domain/models/lom_line_item.dart';
import '../domain/models/lom_material_entry.dart';

@immutable
class FilesState {
  const FilesState({
    required this.isInitialized,
    required this.isLoading,
    required this.isSavingDesign,
    required this.isCustomerEditing,
    required this.isLomExpanded,
    required this.isCccExpanded,
    required this.routeId,
    required this.entityId,
    required this.designId,
    required this.twoWindingDesign,
    required this.coreResult,
    required this.fabricationResult,
    required this.materials,
    required this.lomItems,
    required this.rateOverrides,
    required this.generatedRateKeys,
    required this.customerName,
    required this.customerPlace,
    required this.errorMessage,
  });

  factory FilesState.initial({required String routeId}) {
    return FilesState(
      isInitialized: false,
      isLoading: false,
      isSavingDesign: false,
      isCustomerEditing: false,
      isLomExpanded: true,
      isCccExpanded: false,
      routeId: routeId,
      entityId: '',
      designId: '',
      twoWindingDesign: null,
      coreResult: null,
      fabricationResult: null,
      materials: const <LomMaterialEntry>[],
      lomItems: const <LomLineItem>[],
      rateOverrides: const <String, num>{},
      generatedRateKeys: const <String>[],
      customerName: '',
      customerPlace: '',
      errorMessage: '',
    );
  }

  final bool isInitialized;
  final bool isLoading;
  final bool isSavingDesign;
  final bool isCustomerEditing;
  final bool isLomExpanded;
  final bool isCccExpanded;
  final String routeId;
  final String entityId;
  final String designId;
  final TwoWindingDesign? twoWindingDesign;
  final CoreCalculationResult? coreResult;
  final FabricationCalculationResult? fabricationResult;
  final List<LomMaterialEntry> materials;
  final List<LomLineItem> lomItems;
  final Map<String, num> rateOverrides;
  final List<String> generatedRateKeys;
  final String customerName;
  final String customerPlace;
  final String errorMessage;

  bool get isBusy => isLoading || isSavingDesign;

  bool get hasGenerationContext =>
      twoWindingDesign != null && fabricationResult != null;

  bool get hasSaveContext => entityId.isNotEmpty;

  List<LomLineItem> get displayRows {
    return lomItems
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final row = entry.value;
          final existingIndex = row.readPath('index');
          final existingRateKey = row.readPath('rateKey');
          final isNew = row.boolAt('isNew');

          return LomLineItem.fromJson(<String, dynamic>{
            ...row.toJson(),
            'index': existingIndex is num ? existingIndex : index,
            'isNew': isNew,
            'rateKey': isNew
                ? existingRateKey
                : existingRateKey ?? _rateKeyAt(index),
          });
        })
        .toList(growable: false);
  }

  num get totalCost {
    return displayRows.fold<num>(0, (sum, row) => sum + row.numberAt('cost'));
  }

  String? rateKeyForRow(int index) => _rateKeyAt(index);

  FilesState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isSavingDesign,
    bool? isCustomerEditing,
    bool? isLomExpanded,
    bool? isCccExpanded,
    String? routeId,
    String? entityId,
    String? designId,
    TwoWindingDesign? twoWindingDesign,
    bool clearTwoWindingDesign = false,
    CoreCalculationResult? coreResult,
    bool clearCoreResult = false,
    FabricationCalculationResult? fabricationResult,
    bool clearFabricationResult = false,
    List<LomMaterialEntry>? materials,
    List<LomLineItem>? lomItems,
    Map<String, num>? rateOverrides,
    List<String>? generatedRateKeys,
    String? customerName,
    String? customerPlace,
    String? errorMessage,
  }) {
    return FilesState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isSavingDesign: isSavingDesign ?? this.isSavingDesign,
      isCustomerEditing: isCustomerEditing ?? this.isCustomerEditing,
      isLomExpanded: isLomExpanded ?? this.isLomExpanded,
      isCccExpanded: isCccExpanded ?? this.isCccExpanded,
      routeId: routeId ?? this.routeId,
      entityId: entityId ?? this.entityId,
      designId: designId ?? this.designId,
      twoWindingDesign: clearTwoWindingDesign
          ? null
          : twoWindingDesign ?? this.twoWindingDesign,
      coreResult: clearCoreResult ? null : coreResult ?? this.coreResult,
      fabricationResult: clearFabricationResult
          ? null
          : fabricationResult ?? this.fabricationResult,
      materials: materials ?? this.materials,
      lomItems: lomItems ?? this.lomItems,
      rateOverrides: rateOverrides ?? this.rateOverrides,
      generatedRateKeys: generatedRateKeys ?? this.generatedRateKeys,
      customerName: customerName ?? this.customerName,
      customerPlace: customerPlace ?? this.customerPlace,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String? _rateKeyAt(int index) {
    if (index < 0 || index >= generatedRateKeys.length) {
      return null;
    }
    return generatedRateKeys[index];
  }
}
