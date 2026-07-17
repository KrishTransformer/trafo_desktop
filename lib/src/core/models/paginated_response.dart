import 'package:flutter/foundation.dart';

@immutable
class PaginatedResponse<T> {
  const PaginatedResponse({required this.data, required this.total});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) itemFromJson,
  ) {
    final rawData = json['data'];
    final items = rawData is List<dynamic>
        ? rawData
              .map(
                (item) => itemFromJson(
                  Map<String, dynamic>.from(item as Map<Object?, Object?>),
                ),
              )
              .toList(growable: false)
        : <T>[];

    final totalValue = json['total'];

    return PaginatedResponse<T>(
      data: items,
      total: totalValue is num ? totalValue.toInt() : 0,
    );
  }

  final List<T> data;
  final int total;
}
