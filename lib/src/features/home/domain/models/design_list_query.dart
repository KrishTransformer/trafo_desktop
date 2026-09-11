import 'package:flutter/foundation.dart';

@immutable
class DesignListQuery {
  const DesignListQuery({
    required this.offset,
    required this.size,
    required this.sortAttribute,
    required this.sortOrder,
    this.filters = const <String, dynamic>{},
  });

  final int offset;
  final int size;
  final String sortAttribute;
  final String sortOrder;
  final Map<String, dynamic> filters;

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'offset': offset,
      'size': size,
      'sortAttribute': sortAttribute,
      'sortOrder': sortOrder,
    };
  }

  Map<String, dynamic> toRequestBody() => Map<String, dynamic>.from(filters);
}
