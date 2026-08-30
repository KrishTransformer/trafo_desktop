import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/models/design_summary.dart';

@immutable
class DesignTableRow {
  const DesignTableRow({
    required this.id,
    required this.designId,
    required this.displayDate,
    required this.capacity,
    required this.voltage,
    required this.impedance,
    required this.frame,
    required this.voltsPerTurn,
    required this.losses,
    required this.cost,
    required this.source,
  });

  factory DesignTableRow.fromSummary(DesignSummary summary) {
    final designData = _readJsonMap(
      summary.isMultiWinding ? summary.multiWindings : summary.twoWindings,
    );
    final coreData = _readNestedMap(designData['core']);
    final costData = _readNestedMap(designData['cost']);

    return DesignTableRow(
      id: summary.id,
      designId: summary.designId,
      displayDate: _formatDate(summary.updatedAt ?? summary.createdAt),
      capacity: _formatValue(designData['kVA']),
      voltage: _joinValues(<Object?>[
        designData['lowVoltage'],
        designData['highVoltage'],
      ], separator: '/'),
      impedance: _formatValue(designData['ez']),
      frame: _joinValues(<Object?>[
        coreData['coreDia'],
        coreData['limbHt'],
        coreData['cenDist'],
      ], separator: ' x '),
      voltsPerTurn: _formatValue(designData['voltsPerTurn']),
      losses: _joinValues(<Object?>[
        designData['coreLoss'],
        designData['loadLoss'],
      ], separator: '/'),
      cost: _formatValue(costData['capitalCost']),
      source: summary,
    );
  }

  final String id;
  final String designId;
  final String displayDate;
  final String capacity;
  final String voltage;
  final String impedance;
  final String frame;
  final String voltsPerTurn;
  final String losses;
  final String cost;
  final DesignSummary source;

  static Map<String, Object?> _readJsonMap(Object? rawValue) {
    if (rawValue is Map<Object?, Object?>) {
      return Map<String, Object?>.from(rawValue);
    }

    if (rawValue is Map<String, Object?>) {
      return rawValue;
    }

    if (rawValue is String && rawValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map<Object?, Object?>) {
          return Map<String, Object?>.from(decoded);
        }
      } on FormatException {
        return const <String, Object?>{};
      }
    }

    return const <String, Object?>{};
  }

  static Map<String, Object?> _readNestedMap(Object? value) {
    return _readJsonMap(value);
  }

  static String _formatDate(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return rawValue;
    }

    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '${_twoDigits(parsed.day)}/${_twoDigits(parsed.month)}/${parsed.year} '
        '${_twoDigits(hour)}:${_twoDigits(parsed.minute)}:${_twoDigits(parsed.second)} '
        '$period';
  }

  static String _joinValues(List<Object?> values, {required String separator}) {
    final parts = values
        .map(_stringifyValue)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '-';
    }

    return parts.join(separator);
  }

  static String _formatValue(Object? value) {
    final text = _stringifyValue(value);
    return text.isEmpty ? '-' : text;
  }

  static String _stringifyValue(Object? value) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      return value.trim();
    }

    return value.toString();
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
