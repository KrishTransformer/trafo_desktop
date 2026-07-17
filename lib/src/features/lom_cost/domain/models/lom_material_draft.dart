import 'package:flutter/foundation.dart';

@immutable
class LomMaterialDraft {
  const LomMaterialDraft({
    required this.materialName,
    required this.materialRate,
  });

  final String materialName;
  final num materialRate;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'materialName': materialName,
      'materialRate': materialRate,
    };
  }
}
