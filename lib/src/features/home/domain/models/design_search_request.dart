import 'package:flutter/foundation.dart';

@immutable
class DesignSearchRequest {
  const DesignSearchRequest({
    required this.attributeName,
    required this.attributeValue,
    required this.sortAttribute,
    required this.sortOrder,
  });

  final List<String> attributeName;
  final String attributeValue;
  final String sortAttribute;
  final String sortOrder;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attributeName': attributeName,
      'attributeValue': attributeValue,
      'sortAttribute': sortAttribute,
      'sortOrder': sortOrder,
    };
  }
}
