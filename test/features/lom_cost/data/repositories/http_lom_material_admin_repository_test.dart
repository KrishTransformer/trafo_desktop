import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/lom_cost/data/repositories/http_lom_material_admin_repository.dart';
import 'package:trafo_desktop/src/features/lom_cost/domain/models/lom_material_draft.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpLomMaterialAdminRepository repository;

  setUp(() {
    adapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;
    repository = HttpLomMaterialAdminRepository(apiClient);
  });

  test('createMaterial uses the entity create path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.createMaterial(
      const LomMaterialDraft(materialName: 'Lamination', materialRate: 220.0),
    );

    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.path, '/entity/lomMaterial');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'materialName': 'Lamination',
      'materialRate': 220.0,
    });
  });

  test('updateMaterial uses the entity update path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.updateMaterial(
      entityId: 'mat-1',
      draft: const LomMaterialDraft(
        materialName: 'HV Conductor',
        materialRate: 125.0,
      ),
    );

    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.path, '/entity/lomMaterial/mat-1');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'materialName': 'HV Conductor',
      'materialRate': 125.0,
    });
  });

  test('deleteMaterial uses the entity delete path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.deleteMaterial('mat-9');

    expect(adapter.lastOptions?.method, 'DELETE');
    expect(adapter.lastOptions?.path, '/entity/lomMaterial/mat-9');
  });
}

final AppEnvironment _testEnvironment = AppEnvironment(
  flavor: AppFlavor.development,
  baseUrls: ServiceBaseUrls(
    common: Uri(scheme: 'https', host: 'common.example.com'),
    core: Uri(scheme: 'https', host: 'core.example.com'),
    cad: Uri(scheme: 'https', host: 'cad.example.com'),
    multiWinding: Uri(scheme: 'https', host: 'multi.example.com'),
    storage: Uri(scheme: 'https', host: 'storage.example.com'),
  ),
  connectTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 30),
);

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> writeRefreshToken(String token) async {}
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  Map<String, dynamic>? lastDecodedBody;
  Map<String, dynamic> nextResponseJson = const <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;

    final requestBytes =
        await requestStream
            ?.fold<BytesBuilder>(
              BytesBuilder(),
              (builder, chunk) => builder..add(chunk),
            )
            .then((builder) => builder.takeBytes()) ??
        Uint8List(0);

    if (requestBytes.isNotEmpty) {
      lastDecodedBody =
          jsonDecode(utf8.decode(requestBytes)) as Map<String, dynamic>;
    } else {
      lastDecodedBody = null;
    }

    return ResponseBody.fromString(
      jsonEncode(nextResponseJson),
      200,
      headers: const <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
