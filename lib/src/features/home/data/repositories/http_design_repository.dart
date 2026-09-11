import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/design_list_query.dart';
import '../../domain/models/design_search_request.dart';
import '../../domain/models/design_summary.dart';
import '../../domain/models/paginated_response.dart';
import '../../domain/repositories/design_repository.dart';

class HttpDesignRepository implements DesignRepository {
  HttpDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(DesignListQuery query) {
    return _apiClient.post<PaginatedResponse<DesignSummary>>(
      service: ApiService.common,
      path: '/entity/v2/design',
      data: query.toRequestBody(),
      queryParameters: query.toQueryParameters(),
      decoder: (data) => PaginatedResponse<DesignSummary>.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
        DesignSummary.fromJson,
      ),
    );
  }

  @override
  Future<PaginatedResponse<DesignSummary>> searchDesigns({
    required DesignListQuery query,
    required DesignSearchRequest request,
  }) {
    return _apiClient.post<PaginatedResponse<DesignSummary>>(
      service: ApiService.common,
      path: '/entity/v2/design/search',
      data: request.toJson(),
      queryParameters: query.toQueryParameters(),
      decoder: (data) => PaginatedResponse<DesignSummary>.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
        DesignSummary.fromJson,
      ),
    );
  }

  @override
  Future<void> deleteDesign(String designId) {
    return _apiClient.delete<void>(
      service: ApiService.common,
      path: '/entity/design/$designId',
      decoder: (_) {},
    );
  }
}
