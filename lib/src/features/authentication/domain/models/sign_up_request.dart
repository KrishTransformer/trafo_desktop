import 'package:flutter/foundation.dart';

@immutable
class SignUpRequest {
  const SignUpRequest({
    required this.username,
    required this.password,
    required this.email,
    required this.otp,
  });

  final String username;
  final String password;
  final String email;
  final String otp;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'password': password,
      'email': email,
      'otp': otp,
    };
  }
}
