import 'package:flutter/foundation.dart';

@immutable
class OtpDispatchResult {
  const OtpDispatchResult({required this.issued, required this.sessionInfo});

  factory OtpDispatchResult.fromJson(Map<String, dynamic> json) {
    final sessionInfo = json['sessionInfo'];
    return OtpDispatchResult(
      issued: true,
      sessionInfo: sessionInfo is String ? sessionInfo : '',
    );
  }

  final bool issued;
  final String sessionInfo;
}
