import 'dart:convert';

class CadGenerationResult {
  CadGenerationResult._(this._json);

  factory CadGenerationResult.fromJson(Map<String, dynamic> json) {
    return CadGenerationResult._(_cloneMap(json));
  }

  final Map<String, dynamic> _json;

  Map<String, dynamic> toJson() => _cloneMap(_json);

  String get message {
    final value = _json['message'];
    return value is String ? value : '';
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
