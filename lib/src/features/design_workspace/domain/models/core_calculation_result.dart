import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'core_stack_step.dart';

@immutable
class CoreCalculationResult {
  const CoreCalculationResult._(this._json);

  factory CoreCalculationResult.fromJson(Map<String, dynamic> json) {
    return CoreCalculationResult._(_cloneMap(json));
  }

  final Map<String, dynamic> _json;

  Map<String, dynamic> toJson() => _cloneMap(_json);

  Object? get coreArea => _json['coreArea'];

  Object? get coreWeight => _json['coreWeight'];

  Object? get designedCoreArea => _json['designedCoreArea'];

  String get bladeType => stringAt('eCoreBladeType', fallback: 'CRUSI_3');

  List<CoreStackStep> get bldStacks {
    final rawValue = _json['bldStacks'];
    if (rawValue is! List<dynamic>) {
      return const <CoreStackStep>[];
    }

    final entries = <CoreStackStep>[];
    for (final entry in rawValue) {
      if (entry is Map<Object?, Object?>) {
        entries.add(CoreStackStep.fromJson(Map<String, dynamic>.from(entry)));
        continue;
      }
      if (entry is Map<String, dynamic>) {
        entries.add(CoreStackStep.fromJson(entry));
      }
    }
    return entries;
  }

  Object? readPath(String path) {
    Object? current = _json;
    for (final segment in path.split('.')) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  String stringAt(String path, {String fallback = ''}) {
    final value = readPath(path);
    return switch (value) {
      null => fallback,
      String() => value,
      _ => value.toString(),
    };
  }

  List<List<Object?>> tableAt(String path) {
    final rawValue = readPath(path);
    if (rawValue is! List<dynamic>) {
      return const <List<Object?>>[];
    }

    return rawValue
        .whereType<List>()
        .map((row) => List<Object?>.from(row))
        .toList(growable: false);
  }

  String toDebugJson() => const JsonEncoder.withIndent('  ').convert(_json);

  static Map<String, dynamic> _cloneMap(Map<Object?, Object?> source) {
    return source.map<String, dynamic>((key, value) {
      return MapEntry<String, dynamic>(key.toString(), _cloneValue(value));
    });
  }

  static dynamic _cloneValue(Object? value) {
    if (value is Map<Object?, Object?>) {
      return _cloneMap(value);
    }
    if (value is List<Object?>) {
      return value.map<Object?>((entry) => _cloneValue(entry)).toList();
    }
    if (value is List<dynamic>) {
      return value.map<Object?>((entry) => _cloneValue(entry)).toList();
    }
    return value;
  }
}
