import 'dart:convert';

class LomLineItem {
  LomLineItem._(this._json);

  factory LomLineItem.fromJson(Map<String, dynamic> json) {
    return LomLineItem._(_cloneMap(json));
  }

  final Map<String, dynamic> _json;

  Map<String, dynamic> toJson() => _cloneMap(_json);

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

  num numberAt(String path, {num fallback = 0}) {
    final value = readPath(path);
    return switch (value) {
      num() => value,
      String() => num.tryParse(value) ?? fallback,
      _ => fallback,
    };
  }

  bool boolAt(String path, {bool fallback = false}) {
    final value = readPath(path);
    return switch (value) {
      bool() => value,
      String() => value.toLowerCase() == 'true',
      _ => fallback,
    };
  }

  String get description => stringAt('description');
  String get specification => stringAt('specification');
  String get unit => stringAt('unit');
  num get quantity => numberAt('quantity');
  num get rate => numberAt('rate');
  num get cost => numberAt('cost');

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
