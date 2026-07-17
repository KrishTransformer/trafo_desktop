import 'package:flutter/foundation.dart';

@immutable
class DrawingsStatusCreateRequest {
  const DrawingsStatusCreateRequest({
    required this.designId,
    required this.message,
    required this.status,
  });

  final String designId;
  final String message;
  final String status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'designId': designId,
      'message': message,
      'status': status,
    };
  }
}
