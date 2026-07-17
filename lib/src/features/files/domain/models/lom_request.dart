import 'package:flutter/foundation.dart';

@immutable
class LomRequest {
  LomRequest({
    this.isTrue = true,
    required Map<String, Object?> lomBooleans,
    required Map<String, Object?> lomQuantity,
    required Map<String, Object?> lomRate,
  }) : lomBooleans = Map<String, Object?>.unmodifiable(lomBooleans),
       lomQuantity = Map<String, Object?>.unmodifiable(lomQuantity),
       lomRate = Map<String, Object?>.unmodifiable(lomRate);

  final bool isTrue;
  final Map<String, Object?> lomBooleans;
  final Map<String, Object?> lomQuantity;
  final Map<String, Object?> lomRate;

  Map<String, dynamic> toJson() {
    final normalizedBooleans = <String, Object?>{...lomBooleans};
    final legacyBiMetallic = normalizedBooleans['biMetallicConn'];
    if (!normalizedBooleans.containsKey('biMetallicConnector') &&
        legacyBiMetallic != null) {
      normalizedBooleans['biMetallicConnector'] = legacyBiMetallic;
    }

    final booleanPayload = _pickKnownKeys<Object?>(
      normalizedBooleans,
      _lomBooleanKeys,
    );
    final quantityPayload = _pickKnownKeys<Object?>(
      lomQuantity,
      _lomQuantityKeys,
    );
    final ratePayload = _pickKnownKeys<Object?>(lomRate, _lomRateKeys);

    for (final entry in _conditionalRateKeys.entries) {
      if (booleanPayload[entry.key] == false) {
        ratePayload.remove(entry.value);
      }
    }

    return <String, dynamic>{
      'isTrue': isTrue,
      'lomBooleans': booleanPayload,
      'lomQuantity': quantityPayload,
      'lomRate': ratePayload,
    };
  }

  static Map<String, T> _pickKnownKeys<T>(
    Map<String, T> source,
    Set<String> keys,
  ) {
    final result = <String, T>{};
    for (final key in keys) {
      final value = source[key];
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  static const Set<String> _lomBooleanKeys = <String>{
    'hvCableBox',
    'lvCableBox',
    'hvBushing',
    'lvBushing',
    'permaWood',
    'drainValve',
    'filterValve',
    'samplingValve',
    'relayShutOffValve',
    'thermometerPocket',
    'airReleasePlug',
    'oltc',
    'octc',
    'oti',
    'wti',
    'buchholzRelay',
    'marshallingBox',
    'oilLevelGauge',
    'mog',
    'pressureReliefValve',
    'oilCirculatingPump',
    'avrrtcc',
    'rollers',
    'pumpControlCubicle',
    'biMetallicConnector',
    'fasteners',
  };

  static const Set<String> _lomQuantityKeys = <String>{
    'lamination',
    'hvConductor',
    'lvConductor',
    'hvConnectionLeads',
    'lvConnectionLeads',
    'insulationMaterial',
    'transformerOil',
    'tankLidEtc',
    'hvCableBox',
    'lvCableBox',
    'hvBushing',
    'lvBushing',
    'radiatorsAndHeatExc',
    'permaWood',
    'drainValve',
    'filterValve',
    'samplingValve',
    'relayShutOffValve',
    'breatherSilicaGel',
    'ratingPlate',
    'thermometerPocket',
    'airReleasePlug',
    'coreBoltsAndTieRods',
    'oltc',
    'octc',
    'oti',
    'wti',
    'buchholzRelay',
    'marshallingBox',
    'oilLevelGauge',
    'mog',
    'pressureReliefValve',
    'oilCirculatingPump',
    'avrrtcc',
    'rollers',
    'pumpControlCubicle',
    'biMetallicConnector',
    'fasteners',
    'otherMaterials',
  };

  static const Set<String> _lomRateKeys = <String>{
    'lamination',
    'hvConductor',
    'lvConductor',
    'hvConnectionLeads',
    'lvConnectionLeads',
    'insulationMaterial',
    'transformerOil',
    'tankLidEtc',
    'hvCableBox',
    'lvCableBox',
    'hvBushing',
    'lvBushing',
    'radiatorsAndHeatExc',
    'permaWood',
    'drainValve',
    'filterValve',
    'samplingValve',
    'relayShutOffValve',
    'breatherSilicaGel',
    'ratingPlate',
    'thermometerPocket',
    'airReleasePlug',
    'coreBoltsAndTieRods',
    'oltc',
    'octc',
    'oti',
    'wti',
    'buchholzRelay',
    'marshallingBox',
    'oilLevelGauge',
    'mog',
    'pressureReliefValve',
    'oilCirculatingPump',
    'avrrtcc',
    'rollers',
    'pumpControlCubicle',
    'biMetallicConnector',
    'fasteners',
    'otherMaterials',
  };

  static const Map<String, String> _conditionalRateKeys = <String, String>{
    'hvCableBox': 'hvCableBox',
    'lvCableBox': 'lvCableBox',
    'hvBushing': 'hvBushing',
    'lvBushing': 'lvBushing',
    'drainValve': 'drainValve',
    'filterValve': 'filterValve',
    'samplingValve': 'samplingValve',
    'oltc': 'oltc',
    'octc': 'octc',
    'oilLevelGauge': 'oilLevelGauge',
    'mog': 'mog',
    'pressureReliefValve': 'pressureReliefValve',
    'rollers': 'rollers',
  };
}
