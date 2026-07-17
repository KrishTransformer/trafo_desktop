import 'package:flutter/foundation.dart';

@immutable
class AuthSession {
  const AuthSession({
    required this.idToken,
    required this.refreshToken,
    required this.roles,
    required this.entityId,
    required this.email,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = switch (rawRoles) {
      List<dynamic>() => rawRoles.map((role) => role.toString()).toList(),
      String() when rawRoles.isNotEmpty => <String>[rawRoles],
      _ => const <String>[],
    };

    return AuthSession(
      idToken: _readRequiredString(json, 'idToken'),
      refreshToken: _readOptionalString(json, 'refreshToken'),
      roles: roles,
      entityId: _readOptionalString(json, 'entityId'),
      email: _readOptionalString(json, 'email'),
    );
  }

  final String idToken;
  final String refreshToken;
  final List<String> roles;
  final String entityId;
  final String email;

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('Missing or invalid "$key" in AuthSession JSON.');
  }

  static String _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : '';
  }
}
