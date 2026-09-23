import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../../home/domain/models/design_summary.dart';
import '../../domain/models/lom_line_item.dart';
import '../../domain/repositories/files_design_repository.dart';

class HttpFilesDesignRepository implements FilesDesignRepository {
  HttpFilesDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DesignSummary> fetchDesign(String entityId) {
    return _apiClient.get<DesignSummary>(
      service: ApiService.common,
      path: '/entity/design/$entityId',
      decoder: (data) {
        final json = Map<String, dynamic>.from(data as Map<Object?, Object?>);
        final row = json['data'] is Map<Object?, Object?>
            ? Map<String, dynamic>.from(json['data'] as Map<Object?, Object?>)
            : json;
        return DesignSummary.fromJson(row);
      },
    );
  }

  @override
  Future<void> persistLom({
    required String entityId,
    required List<LomLineItem> items,
  }) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/design/$entityId',
      data: <String, dynamic>{
        'lom': jsonEncode(items.map((item) => item.toJson()).toList()),
      },
      decoder: (_) {},
    );
  }
}
