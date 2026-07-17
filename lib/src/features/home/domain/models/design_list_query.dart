import 'package:flutter/foundation.dart';

@immutable
class DesignListQuery {
  const DesignListQuery({
    required this.offset,
    required this.size,
    required this.sortAttribute,
    required this.sortOrder,
  });

  final int offset;
  final int size;
  final String sortAttribute;
  final String sortOrder;

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'offset': offset,
      'size': size,
      'sortAttribute': sortAttribute,
      'sortOrder': sortOrder,
    };
  }
}
