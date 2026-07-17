import '../../../../core/models/entity_list_query.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/profile_record.dart';

abstract interface class ProfileRepository {
  Future<PaginatedResponse<ProfileRecord>> fetchProfiles(EntityListQuery query);

  Future<void> saveProfile({
    required String entityId,
    required ProfileRecord profile,
  });
}
