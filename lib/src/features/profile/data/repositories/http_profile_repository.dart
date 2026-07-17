import '../../../../core/models/entity_list_query.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/entity_payload_sanitizer.dart';
import '../../domain/models/profile_record.dart';
import '../../domain/repositories/profile_repository.dart';

class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<ProfileRecord>> fetchProfiles(
    EntityListQuery query,
  ) {
    return _apiClient.post<PaginatedResponse<ProfileRecord>>(
      service: ApiService.common,
      path: '/entity/v2/profile',
      data: const <String, dynamic>{},
      queryParameters: query.toQueryParameters(),
      decoder: (data) => PaginatedResponse<ProfileRecord>.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
        ProfileRecord.fromJson,
      ),
    );
  }

  @override
  Future<void> saveProfile({
    required String entityId,
    required ProfileRecord profile,
  }) {
    final sanitized = sanitizeEntityPayload(profile.toJson());
    final path = entityId.isEmpty
        ? '/entity/profile'
        : '/entity/profile/$entityId';

    return _apiClient.put<void>(
      service: ApiService.common,
      path: path,
      data: sanitized,
      decoder: (_) {},
    );
  }
}
