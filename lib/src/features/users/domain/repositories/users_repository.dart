import '../../../../core/models/entity_list_query.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/user_draft.dart';
import '../models/user_record.dart';

abstract interface class UsersRepository {
  Future<PaginatedResponse<UserRecord>> fetchUsers(EntityListQuery query);

  Future<void> createUser(UserDraft user);

  Future<void> updateUser({required String entityId, required UserDraft user});

  Future<void> deleteUser(String entityId);
}
