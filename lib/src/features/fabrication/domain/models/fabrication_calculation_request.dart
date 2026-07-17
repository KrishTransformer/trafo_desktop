import 'dart:convert';

class FabricationCalculationRequest {
  FabricationCalculationRequest._(this._json);

  factory FabricationCalculationRequest.fromJson(Map<String, dynamic> json) {
    return FabricationCalculationRequest._(_cloneMap(json));
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

  FabricationCalculationRequest copyWithPath(String path, Object? value) {
    final next = toJson();
    _writePath(next, path, value);
    return FabricationCalculationRequest._(next);
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

  static void _writePath(
    Map<String, dynamic> target,
    String path,
    Object? value,
  ) {
    final segments = path.split('.');
    var current = target;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (index == segments.length - 1) {
        current[segment] = value;
        return;
      }

      final next = current[segment];
      if (next is Map<String, dynamic>) {
        current = next;
        continue;
      }
      if (next is Map<Object?, Object?>) {
        final converted = Map<String, dynamic>.from(next);
        current[segment] = converted;
        current = converted;
        continue;
      }

      final created = <String, dynamic>{};
      current[segment] = created;
      current = created;
    }
  }
}
