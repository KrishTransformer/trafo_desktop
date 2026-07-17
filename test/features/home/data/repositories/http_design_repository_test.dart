import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/home/data/repositories/http_design_repository.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpDesignRepository repository;

  setUp(() {
    adapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;

    repository = HttpDesignRepository(apiClient);
  });

  test(
    'fetchDesigns posts to the design list endpoint and parses rows',
    () async {
      adapter.nextResponseJson = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'entity-1',
            'designId': '100k-82911',
            'twoWindings': '{"kVA":100,"ez":4.5}',
            'core': '{"designedCoreArea":1234}',
            'fabrication': '{"designId":"100k-82911"}',
            'lom': '[{"description":"Copper"}]',
            'createdAt': '2026-07-15T08:00:00.000Z',
            'updatedAt': '2026-07-15T10:00:00.000Z',
          },
        ],
        'total': 1,
      };

      final response = await repository.fetchDesigns(
        const DesignListQuery(
          offset: 0,
          size: 20,
          sortAttribute: 'updatedAt',
          sortOrder: 'DESC',
        ),
      );

      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.path, '/entity/v2/design');
      expect(adapter.lastOptions?.queryParameters, <String, dynamic>{
        'offset': 0,
        'size': 20,
        'sortAttribute': 'updatedAt',
        'sortOrder': 'DESC',
      });
      expect(adapter.lastDecodedBody, <String, dynamic>{});
      expect(response.total, 1);
      expect(response.data, hasLength(1));
      expect(response.data.first.id, 'entity-1');
      expect(response.data.first.designId, '100k-82911');
      expect(response.data.first.ownerId, isNull);
      expect(response.data.first.toJson(), <String, dynamic>{
        'id': 'entity-1',
        'designId': '100k-82911',
        'twoWindings': '{"kVA":100,"ez":4.5}',
        'core': '{"designedCoreArea":1234}',
        'fabrication': '{"designId":"100k-82911"}',
        'lom': '[{"description":"Copper"}]',
        'createdAt': '2026-07-15T08:00:00.000Z',
        'updatedAt': '2026-07-15T10:00:00.000Z',
      });
    },
  );

  test(
    'searchDesigns preserves the search payload field names exactly',
    () async {
      adapter.nextResponseJson = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'entity-2',
            'designId': '250k-90001',
            'twoWindings': '{"kVA":250}',
            'createdAt': '2026-07-14T08:00:00.000Z',
            'ownerId': 'legacy-owner-7',
          },
        ],
        'total': 1,
      };

      final response = await repository.searchDesigns(
        query: const DesignListQuery(
          offset: 0,
          size: 20,
          sortAttribute: 'updatedAt',
          sortOrder: 'DESC',
        ),
        request: const DesignSearchRequest(
          attributeName: <String>['designId'],
          attributeValue: '250k',
          sortAttribute: 'updatedAt',
          sortOrder: 'DESC',
        ),
      );

      expect(adapter.lastOptions?.path, '/entity/v2/design/search');
      expect(adapter.lastDecodedBody, <String, dynamic>{
        'attributeName': <String>['designId'],
        'attributeValue': '250k',
        'sortAttribute': 'updatedAt',
        'sortOrder': 'DESC',
      });
      expect(response.data.first.ownerId, 'legacy-owner-7');
    },
  );

  test('deleteDesign uses the documented entity delete endpoint', () async {
    adapter.nextResponseJson = <String, dynamic>{'deleted': true};

    await repository.deleteDesign('entity-99');

    expect(adapter.lastOptions?.method, 'DELETE');
    expect(adapter.lastOptions?.path, '/entity/design/entity-99');
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
  Object? lastDecodedBody;
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

    if (requestBytes.isEmpty) {
      lastDecodedBody = null;
    } else {
      lastDecodedBody = jsonDecode(utf8.decode(requestBytes)) as Object?;
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
