import 'package:flutter/foundation.dart';

@immutable
class SignInRequest {
  const SignInRequest({required this.usernameOrEmail, required this.password});

  final String usernameOrEmail;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'usernameOrEmail': usernameOrEmail,
      'password': password,
      if (usernameOrEmail.contains('@'))
        'email': usernameOrEmail
      else
        'username': usernameOrEmail,
    };
  }
}
