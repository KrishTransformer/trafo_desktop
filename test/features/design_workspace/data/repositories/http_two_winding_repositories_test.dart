import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/design_workspace/application/two_winding_controller.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_two_winding_calculation_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_two_winding_design_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';

void main() {
  late _RecordingAdapter adapter;
  late _RecordingAdapter coreAdapter;
  late HttpTwoWindingCalculationRepository calculationRepository;
  late HttpTwoWindingDesignRepository designRepository;

  setUp(() {
    adapter = _RecordingAdapter();
    coreAdapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;
    apiClient.clientFor(ApiService.core).httpClientAdapter = coreAdapter;

    calculationRepository = HttpTwoWindingCalculationRepository(apiClient);
    designRepository = HttpTwoWindingDesignRepository(apiClient);
  });

  test('calculate posts to the documented two-winding endpoint', () async {
    coreAdapter.nextResponseJson = <String, dynamic>{
      'kVA': '100',
      'core': <String, dynamic>{'coreMaterial': 'CRGO'},
    };

    final response = await calculationRepository.calculate(
      TwoWindingDesign.initial().copyWithPath('kVA', '100'),
    );

    expect(coreAdapter.lastOptions?.method, 'POST');
    expect(
      coreAdapter.lastOptions?.uri.toString(),
      'https://core.example.com/tf/api/design.trafointel.com/calculate/2windings/circular',
    );
    expect(coreAdapter.lastOptions?.headers['User-Calc'].toString(), 'true');
    expect(coreAdapter.lastDecodedBody?['kVA'], '100');
    expect(adapter.lastOptions, isNull);
    expect(response.stringAt('kVA'), '100');
    expect(response.stringAt('core.coreMaterial'), 'CRGO');
  });

  test(
    'entering only 200 kVA calculates on core and saves on common',
    () async {
      coreAdapter.nextResponseJson = TwoWindingDesign.initial()
          .copyWithPath('kVA', 200)
          .copyWithPath('core.coreDia', 250)
          .toJson();
      adapter.nextResponseJson = <String, dynamic>{'id': 'saved-200'};
      final controller = TwoWindingController(
        routeId: 'new',
        calculationRepository: calculationRepository,
        designRepository: designRepository,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.setField('kVA', '200');

      expect(await controller.calculate(), isTrue);

      final payload = coreAdapter.lastDecodedBody!;
      expect(payload, containsPair('kVA', '200'));
      expect(payload, containsPair('lowVoltage', 433));
      expect(payload, containsPair('highVoltage', 11000));
      expect(payload, containsPair('frequency', '50'));
      expect(payload, containsPair('fluxDensity', 1.7333));
      expect(payload, containsPair('vectorGroup', 'Dyn11'));
      expect(payload, containsPair('lvWindingType', 'HELICAL'));
      expect(payload, containsPair('hvWindingType', 'HELICAL'));
      expect(payload, containsPair('lvCurrentDensity', '4.24'));
      expect(payload, containsPair('hvCurrentDensity', '4.24'));
      expect(payload, containsPair('buildFactor', 1.3));
      expect(payload, containsPair('topOilTemp', '50'));
      expect(payload['core']['coreMaterial'], 'NipM4');
      expect(payload['core']['coreType'], 'PRIME');
      expect(payload['core']['coreDia'], isNull);
      expect(payload['innerWindings']['turnsPerPhase'], isNull);
      expect(payload['outerWindings']['turnsPerPhase'], isNull);
      expect(adapter.lastOptions?.uri.host, 'common.example.com');
      expect(adapter.lastOptions?.method, 'PUT');
      expect(adapter.lastOptions?.path, '/entity/design');
      expect(adapter.lastOptions?.responseType, ResponseType.plain);
      expect(adapter.lastDecodedBody?['designType'], 'two');
      expect(controller.state.design.readPath('core.coreDia'), 250);
      expect(controller.state.metadata.entityId, 'saved-200');
      expect(controller.state.errorMessage, isEmpty);
    },
  );

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
      expect(requestBody['designType'], 'two');
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

  test(
    'createDesign accepts the common service plain-text id response',
    () async {
      adapter.nextResponseBody = 'plain-entity-9';

      final entityId = await designRepository.createDesign(
        designId: '100k-12345',
        design: TwoWindingDesign.initial().copyWithPath(
          'designId',
          '100k-12345',
        ),
      );

      expect(adapter.lastOptions?.responseType, ResponseType.plain);
      expect(entityId, 'plain-entity-9');
    },
  );
}

final AppEnvironment _testEnvironment = AppEnvironment(
  flavor: AppFlavor.development,
  baseUrls: ServiceBaseUrls(
    common: Uri(scheme: 'https', host: 'common.example.com'),
    core: Uri.parse('https://core.example.com/tf/api/design.trafointel.com'),
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
  String? nextResponseBody;

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

    final responseBody = nextResponseBody ?? jsonEncode(nextResponseJson);
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: <String, List<String>>{
        'content-type': <String>[
          nextResponseBody == null ? 'application/json' : 'text/plain',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
