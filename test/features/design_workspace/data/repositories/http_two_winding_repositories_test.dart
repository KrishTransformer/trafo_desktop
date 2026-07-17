import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_two_winding_calculation_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_two_winding_design_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpTwoWindingCalculationRepository calculationRepository;
  late HttpTwoWindingDesignRepository designRepository;

  setUp(() {
    adapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;

    calculationRepository = HttpTwoWindingCalculationRepository(apiClient);
    designRepository = HttpTwoWindingDesignRepository(apiClient);
  });

  test('calculate posts to the documented two-winding endpoint', () async {
    adapter.nextResponseJson = <String, dynamic>{
      'kVA': '100',
      'core': <String, dynamic>{'coreMaterial': 'CRGO'},
    };

    final response = await calculationRepository.calculate(
      TwoWindingDesign.initial().copyWithPath('kVA', '100'),
    );

    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.path, '/calculate/2windings/circular');
    expect(adapter.lastDecodedBody?['kVA'], '100');
    expect(response.stringAt('kVA'), '100');
    expect(response.stringAt('core.coreMaterial'), 'CRGO');
  });

  test(
    'createDesign stringifies and sanitizes the persisted two-winding payload',
    () async {
      adapter.nextResponseJson = <String, dynamic>{'id': 'entity-7'};

      final entityId = await designRepository.createDesign(
        designId: '100k-12345',
        design: TwoWindingDesign.fromJson(<String, dynamic>{
          'designId': '100k-12345',
          'ownerId': 'legacy-owner',
          'core': <String, dynamic>{'coreMaterial': 'CRGO'},
          'innerWindings': <String, dynamic>{
            'turnsPerPhase': '12',
            'tenantUrl': 'should-be-removed',
          },
        }),
      );

      final requestBody = adapter.lastDecodedBody!;
      expect(adapter.lastOptions?.method, 'PUT');
      expect(adapter.lastOptions?.path, '/entity/design');
      expect(requestBody['designId'], '100k-12345');
      expect(requestBody['twoWindings'], isA<String>());

      final persistedJson =
          jsonDecode(requestBody['twoWindings'] as String)
              as Map<String, dynamic>;
      expect(persistedJson.containsKey('ownerId'), isFalse);
      expect(
        (persistedJson['innerWindings'] as Map<String, dynamic>).containsKey(
          'tenantUrl',
        ),
        isFalse,
      );
      expect(entityId, 'entity-7');
    },
  );
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
