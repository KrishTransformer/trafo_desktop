import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/fabrication_calculation_result.dart';
import '../../domain/repositories/fabrication_design_repository.dart';

class HttpFabricationDesignRepository implements FabricationDesignRepository {
  HttpFabricationDesignRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> persistFabrication({
    required String entityId,
    required FabricationCalculationResult fabrication,
  }) {
    return _apiClient.put<void>(
      service: ApiService.common,
      path: '/entity/design/$entityId',
      data: <String, dynamic>{'fabrication': jsonEncode(fabrication.toJson())},
      decoder: (_) {},
    );
  }
}
