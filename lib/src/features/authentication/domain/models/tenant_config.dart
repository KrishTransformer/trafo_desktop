import 'package:flutter/foundation.dart';

@immutable
class TenantConfig {
  const TenantConfig({required this.tenantName});

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final tenantName = json['tenantName'];
    return TenantConfig(tenantName: tenantName is String ? tenantName : '');
  }

  final String tenantName;
}
