import 'package:flutter/foundation.dart';

import '../domain/models/two_winding_design.dart';
import '../domain/models/two_winding_metadata.dart';

@immutable
class TwoWindingState {
  const TwoWindingState({
    required this.isInitialized,
    required this.isCalculating,
    required this.metadata,
    required this.design,
    required this.expandedMoreInfo,
    required this.hoveredCommentKey,
    required this.errorMessage,
  });

  factory TwoWindingState.initial({required String routeId}) {
    return TwoWindingState(
      isInitialized: false,
      isCalculating: false,
      metadata: TwoWindingMetadata.initial(routeId: routeId),
      design: TwoWindingDesign.initial(),
      expandedMoreInfo: false,
      hoveredCommentKey: '',
      errorMessage: '',
    );
  }

  final bool isInitialized;
  final bool isCalculating;
  final TwoWindingMetadata metadata;
  final TwoWindingDesign design;
  final bool expandedMoreInfo;
  final String hoveredCommentKey;
  final String errorMessage;

  bool get isBusy => isCalculating;

  String get activeComment {
    if (hoveredCommentKey.isEmpty) {
      return '';
    }
    return design.stringAt('comments.$hoveredCommentKey');
  }

  TwoWindingState copyWith({
    bool? isInitialized,
    bool? isCalculating,
    TwoWindingMetadata? metadata,
    TwoWindingDesign? design,
    bool? expandedMoreInfo,
    String? hoveredCommentKey,
    String? errorMessage,
  }) {
    return TwoWindingState(
      isInitialized: isInitialized ?? this.isInitialized,
      isCalculating: isCalculating ?? this.isCalculating,
      metadata: metadata ?? this.metadata,
      design: design ?? this.design,
      expandedMoreInfo: expandedMoreInfo ?? this.expandedMoreInfo,
      hoveredCommentKey: hoveredCommentKey ?? this.hoveredCommentKey,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
