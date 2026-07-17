import 'package:flutter/foundation.dart';

import '../../design_workspace/domain/models/core_calculation_request.dart';
import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';

@immutable
class CoreModelState {
  const CoreModelState({
    required this.isInitialized,
    required this.isLoading,
    required this.routeId,
    required this.entityId,
    required this.designId,
    required this.twoWindingDesign,
    required this.request,
    required this.result,
    required this.selectedStepNo,
    required this.editedWidth,
    required this.editedStack,
    required this.errorMessage,
  });

  factory CoreModelState.initial({required String routeId}) {
    return CoreModelState(
      isInitialized: false,
      isLoading: false,
      routeId: routeId,
      entityId: '',
      designId: '',
      twoWindingDesign: null,
      request: const CoreCalculationRequest(
        coreDiameter: null,
        limbHt: null,
        cenDist: null,
        minimumStepWidth: 0,
        numberOfSteps: 0,
        fixtureStepWidth: null,
        eCoreBladeType: 'CRUSI_3',
        coreStackRequestList: <Never>[],
        prevCoreStackRequestList: <Never>[],
      ),
      result: null,
      selectedStepNo: null,
      editedWidth: '',
      editedStack: '',
      errorMessage: '',
    );
  }

  final bool isInitialized;
  final bool isLoading;
  final String routeId;
  final String entityId;
  final String designId;
  final TwoWindingDesign? twoWindingDesign;
  final CoreCalculationRequest request;
  final CoreCalculationResult? result;
  final Object? selectedStepNo;
  final String editedWidth;
  final String editedStack;
  final String errorMessage;

  bool get isBusy => isLoading;

  bool get hasDesignContext => twoWindingDesign != null && entityId.isNotEmpty;

  bool get hasCoreResult => result != null;

  CoreModelState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? routeId,
    String? entityId,
    String? designId,
    TwoWindingDesign? twoWindingDesign,
    bool clearTwoWindingDesign = false,
    CoreCalculationRequest? request,
    CoreCalculationResult? result,
    bool clearResult = false,
    Object? selectedStepNo = _sentinel,
    String? editedWidth,
    String? editedStack,
    String? errorMessage,
  }) {
    return CoreModelState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      routeId: routeId ?? this.routeId,
      entityId: entityId ?? this.entityId,
      designId: designId ?? this.designId,
      twoWindingDesign: clearTwoWindingDesign
          ? null
          : twoWindingDesign ?? this.twoWindingDesign,
      request: request ?? this.request,
      result: clearResult ? null : result ?? this.result,
      selectedStepNo: identical(selectedStepNo, _sentinel)
          ? this.selectedStepNo
          : selectedStepNo,
      editedWidth: editedWidth ?? this.editedWidth,
      editedStack: editedStack ?? this.editedStack,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

const Object _sentinel = Object();
