import '../models/design_list_query.dart';
import '../models/design_search_request.dart';
import '../models/design_summary.dart';
import '../models/paginated_response.dart';

abstract interface class DesignRepository {
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(DesignListQuery query);

  Future<PaginatedResponse<DesignSummary>> searchDesigns({
    required DesignListQuery query,
    required DesignSearchRequest request,
  });

  Future<void> deleteDesign(String designId);
}
