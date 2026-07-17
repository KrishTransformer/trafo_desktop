import 'package:flutter/foundation.dart';

@immutable
class UserRecord {
  const UserRecord({required this.id, required this.name, required this.email});

  const UserRecord.empty() : id = '', name = '', email = '';

  factory UserRecord.fromJson(Map<String, dynamic> json) {
    return UserRecord(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      email: _readString(json, 'email'),
    );
  }

  final String id;
  final String name;
  final String email;

  UserRecord copyWith({String? id, String? name, String? email}) {
    return UserRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value : '';
  }
}
