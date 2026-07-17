import '../../../../core/models/entity_list_query.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/entity_payload_sanitizer.dart';
import '../../domain/models/user_draft.dart';
import '../../domain/models/user_record.dart';
import '../../domain/repositories/users_repository.dart';

class HttpUsersRepository implements UsersRepository {
  HttpUsersRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<UserRecord>> fetchUsers(EntityListQuery query) {
    return _apiClient.post<PaginatedResponse<UserRecord>>(
      service: ApiService.common,
      path: '/entity/v2/users',
      data: const <String, dynamic>{},
      queryParameters: query.toQueryParameters(),
      decoder: (data) => PaginatedResponse<UserRecord>.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
        UserRecord.fromJson,
      ),
    );
  }

  @override
  Future<void> createUser(UserDraft user) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/users',
      data: sanitizeEntityPayload(user.toJson()),
      decoder: (_) {},
    );
  }

  @override
  Future<void> updateUser({required String entityId, required UserDraft user}) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/users/$entityId',
      data: sanitizeEntityPayload(user.toJson()),
      decoder: (_) {},
    );
  }

  @override
  Future<void> deleteUser(String entityId) {
    return _apiClient.delete<void>(
      service: ApiService.common,
      path: '/entity/users/$entityId',
      decoder: (_) {},
    );
  }
}
