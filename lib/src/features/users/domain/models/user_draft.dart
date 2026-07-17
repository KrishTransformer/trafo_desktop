import 'package:flutter/foundation.dart';

@immutable
class UserDraft {
  const UserDraft({required this.name, required this.email});

  final String name;
  final String email;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'email': email};
  }
}
