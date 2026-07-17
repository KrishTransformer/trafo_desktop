import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../home/domain/models/paginated_response.dart';
import '../../domain/models/drawings_status_create_request.dart';
import '../../domain/models/drawings_status_entry.dart';
import '../../domain/repositories/drawings_status_repository.dart';

class HttpDrawingsStatusRepository implements DrawingsStatusRepository {
  HttpDrawingsStatusRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<DrawingsStatusEntry>> fetchStatuses({
    required String designId,
    int offset = 0,
    int size = 30,
  }) {
    return _apiClient.post<PaginatedResponse<DrawingsStatusEntry>>(
      service: ApiService.common,
      path: '/entity/v2/drawingsStatus',
      data: <String, dynamic>{
        'designId': <String>[designId],
      },
      queryParameters: <String, dynamic>{'offset': offset, 'size': size},
      decoder: (data) => PaginatedResponse<DrawingsStatusEntry>.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
        DrawingsStatusEntry.fromJson,
      ),
    );
  }

  @override
  Future<void> createStatus(DrawingsStatusCreateRequest request) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/drawingsStatus',
      data: request.toJson(),
      decoder: (_) {},
    );
  }

  @override
  Future<void> deleteStatus(String entityId) {
    return _apiClient.delete<void>(
      service: ApiService.common,
      path: '/entity/drawingsStatus/$entityId',
      decoder: (_) {},
    );
  }
}
