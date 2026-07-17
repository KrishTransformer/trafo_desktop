import 'package:flutter/foundation.dart';

@immutable
class StoredCadModel {
  const StoredCadModel({required this.bytes});

  final Uint8List bytes;
}
