import 'package:flutter/foundation.dart';

@immutable
class ForgotPasswordRequest {
  const ForgotPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  final String email;
  final String otp;
  final String newPassword;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    };
  }
}
