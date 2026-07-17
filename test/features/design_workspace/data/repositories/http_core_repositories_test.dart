import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_core_calculation_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/data/repositories/http_core_design_repository.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_request.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_result.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_stack_request_entry.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpCoreCalculationRepository calculationRepository;
  late HttpCoreDesignRepository designRepository;

  setUp(() {
    adapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;

    calculationRepository = HttpCoreCalculationRepository(apiClient);
    designRepository = HttpCoreDesignRepository(apiClient);
  });

  test('calculate posts to the documented core endpoint', () async {
    adapter.nextResponseJson = <String, dynamic>{
      'coreArea': 1234,
      'bldStacks': <Map<String, dynamic>>[
        <String, dynamic>{'stepNo': 1, 'width': 45, 'stack': 30},
      ],
    };

    final response = await calculationRepository.calculate(
      CoreCalculationRequest.initial(
        coreDiameter: 220,
        limbHt: 560,
        cenDist: 340,
      ).copyWith(
        minimumStepWidth: 12,
        numberOfSteps: 8,
        fixtureStepWidth: 20,
        eCoreBladeType: 'BLADE_4',
        coreStackRequestList: const <CoreStackRequestEntry>[
          CoreStackRequestEntry(stepNo: 1, width: 45, stack: 30),
        ],
      ),
    );

    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.path, '/calculate/core');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'coreDiameter': 220,
      'limbHt': 560,
      'cenDist': 340,
      'minimumStepWidth': 12,
      'numberOfSteps': 8,
      'fixtureStepWidth': 20,
      'eCoreBladeType': 'BLADE_4',
      'coreStackRequestList': <Map<String, dynamic>>[
        <String, dynamic>{'stepNo': 1, 'width': 45, 'stack': 30},
      ],
      'prevCoreStackRequestList': <Map<String, dynamic>>[],
    });
    expect(response.stringAt('coreArea'), '1234');
    expect(response.bldStacks.single.width, 45);
  });

  test(
    'persistCore updates the existing design entity with serialized core JSON',
    () async {
      adapter.nextResponseJson = const <String, dynamic>{};

      await designRepository.persistCore(
        entityId: 'entity-7',
        core: CoreCalculationResult.fromJson(<String, dynamic>{
          'coreArea': 1234,
          'bldStacks': <Map<String, dynamic>>[
            <String, dynamic>{'stepNo': 1, 'width': 45, 'stack': 30},
          ],
        }),
      );

      final requestBody = adapter.lastDecodedBody!;
      expect(adapter.lastOptions?.method, 'PUT');
      expect(adapter.lastOptions?.path, '/entity/design/entity-7');
      expect(requestBody.keys, <String>['core']);
      expect(requestBody['core'], isA<String>());
      expect(jsonDecode(requestBody['core'] as String), <String, dynamic>{
        'coreArea': 1234,
        'bldStacks': <Map<String, dynamic>>[
          <String, dynamic>{'stepNo': 1, 'width': 45, 'stack': 30},
        ],
      });
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
