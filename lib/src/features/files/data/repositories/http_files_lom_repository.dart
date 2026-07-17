import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/lom_line_item.dart';
import '../../domain/models/lom_request.dart';
import '../../domain/repositories/files_lom_repository.dart';

class HttpFilesLomRepository implements FilesLomRepository {
  HttpFilesLomRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<LomLineItem>> generateLom(LomRequest request) {
    return _apiClient.post<List<LomLineItem>>(
      service: ApiService.core,
      path: '/files/lom',
      data: request.toJson(),
      decoder: (data) {
        final rawItems = data as List<dynamic>? ?? const <dynamic>[];
        return rawItems
            .map(
              (item) => LomLineItem.fromJson(
                Map<String, dynamic>.from(item as Map<Object?, Object?>),
              ),
            )
            .toList(growable: false);
      },
    );
  }
}
