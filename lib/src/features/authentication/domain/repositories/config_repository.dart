import '../models/tenant_config.dart';

abstract interface class ConfigRepository {
  Future<TenantConfig> fetchConfig();
}
