import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/tenant_config.dart';
import '../../domain/repositories/config_repository.dart';

class HttpConfigRepository implements ConfigRepository {
  HttpConfigRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<TenantConfig> fetchConfig() {
    return _apiClient.get<TenantConfig>(
      service: ApiService.common,
      path: '/config',
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return TenantConfig.fromJson(data);
        }
        if (data is Map<Object?, Object?>) {
          return TenantConfig.fromJson(Map<String, dynamic>.from(data));
        }
        return const TenantConfig(tenantName: '');
      },
    );
  }
}
