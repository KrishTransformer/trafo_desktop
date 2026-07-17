import 'package:flutter/foundation.dart';

@immutable
class CoreStackStep {
  const CoreStackStep({this.stepNo, this.width, this.stack});

  factory CoreStackStep.fromJson(Map<String, dynamic> json) {
    return CoreStackStep(
      stepNo: json['stepNo'],
      width: json['width'],
      stack: json['stack'],
    );
  }

  final Object? stepNo;
  final Object? width;
  final Object? stack;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'stepNo': stepNo, 'width': width, 'stack': stack};
  }
}
