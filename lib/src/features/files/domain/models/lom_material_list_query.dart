import 'package:flutter/foundation.dart';

@immutable
class LomMaterialListQuery {
  const LomMaterialListQuery({
    this.offset = 0,
    this.size = 100,
    this.sortAttribute = 'createdAt',
    this.sortOrder = 'ASC',
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
