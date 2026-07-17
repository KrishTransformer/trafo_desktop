import 'package:flutter/foundation.dart';

@immutable
class DesignSummary {
  const DesignSummary({
    required this.id,
    required this.designId,
    this.twoWindings,
    this.core,
    this.fabrication,
    this.lom,
    this.createdAt,
    this.updatedAt,
    this.ownerId,
  });

  factory DesignSummary.fromJson(Map<String, dynamic> json) {
    return DesignSummary(
      id: _readRequiredString(json, 'id'),
      designId: _readRequiredString(json, 'designId'),
      twoWindings: json['twoWindings'],
      core: json['core'],
      fabrication: json['fabrication'],
      lom: json['lom'],
      createdAt: _readOptionalString(json, 'createdAt'),
      updatedAt: _readOptionalString(json, 'updatedAt'),
      ownerId: _readOptionalString(json, 'ownerId'),
    );
  }

  final String id;
  final String designId;
  final Object? twoWindings;
  final Object? core;
  final Object? fabrication;
  final Object? lom;
  final String? createdAt;
  final String? updatedAt;
  final String? ownerId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'designId': designId,
      'twoWindings': twoWindings,
      'core': core,
      'fabrication': fabrication,
      'lom': lom,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (ownerId != null) 'ownerId': ownerId,
    };
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('Missing or invalid "$key" in DesignSummary JSON.');
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }
}
