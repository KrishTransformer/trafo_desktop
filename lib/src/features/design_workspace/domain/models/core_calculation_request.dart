import 'package:flutter/foundation.dart';

import 'core_stack_request_entry.dart';

@immutable
class CoreCalculationRequest {
  const CoreCalculationRequest({
    required this.coreDiameter,
    required this.limbHt,
    required this.cenDist,
    required this.minimumStepWidth,
    required this.numberOfSteps,
    required this.fixtureStepWidth,
    required this.eCoreBladeType,
    required this.coreStackRequestList,
    required this.prevCoreStackRequestList,
  });

  factory CoreCalculationRequest.initial({
    required Object? coreDiameter,
    required Object? limbHt,
    required Object? cenDist,
  }) {
    return CoreCalculationRequest(
      coreDiameter: coreDiameter,
      limbHt: limbHt,
      cenDist: cenDist,
      minimumStepWidth: 0,
      numberOfSteps: 0,
      fixtureStepWidth: null,
      eCoreBladeType: 'CRUSI_3',
      coreStackRequestList: const <CoreStackRequestEntry>[],
      prevCoreStackRequestList: const <CoreStackRequestEntry>[],
    );
  }

  factory CoreCalculationRequest.fromJson(Map<String, dynamic> json) {
    return CoreCalculationRequest(
      coreDiameter: json['coreDiameter'],
      limbHt: json['limbHt'],
      cenDist: json['cenDist'],
      minimumStepWidth: json['minimumStepWidth'],
      numberOfSteps: json['numberOfSteps'],
      fixtureStepWidth: json['fixtureStepWidth'],
      eCoreBladeType: _readBladeType(json['eCoreBladeType']),
      coreStackRequestList: _readEntries(json['coreStackRequestList']),
      prevCoreStackRequestList: _readEntries(json['prevCoreStackRequestList']),
    );
  }

  final Object? coreDiameter;
  final Object? limbHt;
  final Object? cenDist;
  final Object? minimumStepWidth;
  final Object? numberOfSteps;
  final Object? fixtureStepWidth;
  final String eCoreBladeType;
  final List<CoreStackRequestEntry> coreStackRequestList;
  final List<CoreStackRequestEntry> prevCoreStackRequestList;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coreDiameter': coreDiameter,
      'limbHt': limbHt,
      'cenDist': cenDist,
      'minimumStepWidth': minimumStepWidth,
      'numberOfSteps': numberOfSteps,
      'fixtureStepWidth': fixtureStepWidth,
      'eCoreBladeType': eCoreBladeType,
      'coreStackRequestList': coreStackRequestList
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'prevCoreStackRequestList': prevCoreStackRequestList
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  CoreCalculationRequest copyWith({
    Object? coreDiameter,
    Object? limbHt,
    Object? cenDist,
    Object? minimumStepWidth,
    Object? numberOfSteps,
    Object? fixtureStepWidth = _sentinel,
    String? eCoreBladeType,
    List<CoreStackRequestEntry>? coreStackRequestList,
    List<CoreStackRequestEntry>? prevCoreStackRequestList,
  }) {
    return CoreCalculationRequest(
      coreDiameter: coreDiameter ?? this.coreDiameter,
      limbHt: limbHt ?? this.limbHt,
      cenDist: cenDist ?? this.cenDist,
      minimumStepWidth: minimumStepWidth ?? this.minimumStepWidth,
      numberOfSteps: numberOfSteps ?? this.numberOfSteps,
      fixtureStepWidth: identical(fixtureStepWidth, _sentinel)
          ? this.fixtureStepWidth
          : fixtureStepWidth,
      eCoreBladeType: eCoreBladeType ?? this.eCoreBladeType,
      coreStackRequestList: coreStackRequestList ?? this.coreStackRequestList,
      prevCoreStackRequestList:
          prevCoreStackRequestList ?? this.prevCoreStackRequestList,
    );
  }

  static List<CoreStackRequestEntry> _readEntries(Object? rawValue) {
    if (rawValue is! List<dynamic>) {
      return const <CoreStackRequestEntry>[];
    }

    final entries = <CoreStackRequestEntry>[];
    for (final entry in rawValue) {
      if (entry is Map<Object?, Object?>) {
        entries.add(
          CoreStackRequestEntry.fromJson(Map<String, dynamic>.from(entry)),
        );
        continue;
      }
      if (entry is Map<String, dynamic>) {
        entries.add(CoreStackRequestEntry.fromJson(entry));
      }
    }
    return entries;
  }

  static String _readBladeType(Object? rawValue) {
    return rawValue is String && rawValue.isNotEmpty ? rawValue : 'CRUSI_3';
  }
}

const Object _sentinel = Object();
