import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/core_calculation_result.dart';
import '../../domain/repositories/core_design_repository.dart';

class HttpCoreDesignRepository implements CoreDesignRepository {
  HttpCoreDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> persistCore({
    required String entityId,
    required CoreCalculationResult core,
  }) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/design/$entityId',
      data: <String, dynamic>{'core': jsonEncode(core.toJson())},
      decoder: (_) {},
    );
  }
}
