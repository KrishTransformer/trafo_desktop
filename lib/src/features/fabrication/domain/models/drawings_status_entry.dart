import 'package:flutter/foundation.dart';

@immutable
class DrawingsStatusEntry {
  const DrawingsStatusEntry({
    required this.id,
    required this.designId,
    required this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory DrawingsStatusEntry.fromJson(Map<String, dynamic> json) {
    return DrawingsStatusEntry(
      id: _readRequiredString(json, 'id'),
      designId: _readRequiredString(json, 'designId'),
      message: _readRequiredString(json, 'message'),
      status: _readRequiredString(json, 'status'),
      createdAt: _readOptionalString(json, 'createdAt'),
      updatedAt: _readOptionalString(json, 'updatedAt'),
    );
  }

  final String id;
  final String designId;
  final String message;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'designId': designId,
      'message': message,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException(
      'Missing or invalid "$key" in DrawingsStatusEntry JSON.',
    );
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }
}
