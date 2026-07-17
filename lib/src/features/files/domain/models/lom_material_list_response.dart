import 'package:flutter/foundation.dart';

import 'lom_material_entry.dart';

@immutable
class LomMaterialListResponse {
  const LomMaterialListResponse({required this.data, required this.total});

  factory LomMaterialListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final items = rawData is List<dynamic>
        ? rawData
              .map(
                (item) => LomMaterialEntry.fromJson(
                  Map<String, dynamic>.from(item as Map<Object?, Object?>),
                ),
              )
              .toList(growable: false)
        : <LomMaterialEntry>[];

    final totalValue = json['total'];

    return LomMaterialListResponse(
      data: items,
      total: totalValue is num ? totalValue.toInt() : 0,
    );
  }

  final List<LomMaterialEntry> data;
  final int total;
}
