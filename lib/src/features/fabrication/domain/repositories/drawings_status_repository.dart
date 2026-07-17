import '../../../home/domain/models/paginated_response.dart';
import '../models/drawings_status_create_request.dart';
import '../models/drawings_status_entry.dart';

abstract interface class DrawingsStatusRepository {
  Future<PaginatedResponse<DrawingsStatusEntry>> fetchStatuses({
    required String designId,
    int offset = 0,
    int size = 30,
  });

  Future<void> createStatus(DrawingsStatusCreateRequest request);

  Future<void> deleteStatus(String entityId);
}
