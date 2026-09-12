import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/fabrication/data/repositories/http_drawings_status_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/data/repositories/http_fabrication_cad_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/data/repositories/http_fabrication_calculation_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/data/repositories/http_fabrication_design_repository.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/cad_generation_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/drawings_status_create_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_request.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_result.dart';

void main() {
  late _RecordingAdapter commonAdapter;
  late _RecordingAdapter coreAdapter;
  late _RecordingAdapter cadAdapter;
  late _RecordingAdapter storageAdapter;
  late HttpFabricationCalculationRepository calculationRepository;
  late HttpFabricationDesignRepository designRepository;
  late HttpFabricationCadRepository cadRepository;
  late HttpDrawingsStatusRepository drawingsStatusRepository;

  setUp(() {
    commonAdapter = _RecordingAdapter();
    coreAdapter = _RecordingAdapter();
    cadAdapter = _RecordingAdapter();
    storageAdapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = commonAdapter;
    apiClient.clientFor(ApiService.core).httpClientAdapter = coreAdapter;
    apiClient.clientFor(ApiService.cad).httpClientAdapter = cadAdapter;
    apiClient.clientFor(ApiService.storage).httpClientAdapter = storageAdapter;

    calculationRepository = HttpFabricationCalculationRepository(apiClient);
    designRepository = HttpFabricationDesignRepository(apiClient);
    cadRepository = HttpFabricationCadRepository(apiClient);
    drawingsStatusRepository = HttpDrawingsStatusRepository(apiClient);
  });

  test('calculate posts to the documented fabrication endpoint', () async {
    coreAdapter.nextResponseJson = <String, dynamic>{
      'restOfVariables': <String, dynamic>{'designId': '100k-12345'},
      'tank': <String, dynamic>{'tank_L': 1000},
    };

    final response = await calculationRepository.calculate(
      FabricationCalculationRequest.fromJson(<String, dynamic>{
        'designId': '100k-12345',
        'kVA': '100',
        'tank_L': 1000,
        'hvb_Pos': 'lid',
      }),
    );

    expect(coreAdapter.lastOptions?.method, 'POST');
    expect(coreAdapter.lastOptions?.path, '/calculate/fabrication');
    expect(coreAdapter.lastDecodedBody, <String, dynamic>{
      'designId': '100k-12345',
      'kVA': '100',
      'tank_L': 1000,
      'hvb_Pos': 'lid',
    });
    expect(response.stringAt('restOfVariables.designId'), '100k-12345');
    expect(response.stringAt('tank.tank_L'), '1000');
  });

  test(
    'persistFabrication updates the existing design entity with serialized fabrication JSON',
    () async {
      commonAdapter.nextResponseJson = const <String, dynamic>{};

      final fabrication = FabricationCalculationResult.fromJson(
        <String, dynamic>{
          'tank': <String, dynamic>{'tank_L': 1000},
          'restOfVariables': <String, dynamic>{'designId': '100k-12345'},
        },
      );

      await designRepository.persistFabrication(
        entityId: 'entity-9',
        fabrication: fabrication,
      );

      final requestBody = commonAdapter.lastDecodedBody!;
      expect(commonAdapter.lastOptions?.method, 'PUT');
      expect(commonAdapter.lastOptions?.path, '/entity/design/entity-9');
      expect(requestBody.keys, <String>['fabrication']);
      expect(
        jsonDecode(requestBody['fabrication'] as String),
        <String, dynamic>{
          'tank': <String, dynamic>{'tank_L': 1000},
          'restOfVariables': <String, dynamic>{'designId': '100k-12345'},
        },
      );
    },
  );

  test('generate3D posts to the CAD service with file params', () async {
    cadAdapter.nextResponseJson = <String, dynamic>{
      'message': 'fabrication generation requested',
    };

    final response = await cadRepository.generate3D(
      const CadGenerationRequest(
        payload: <String, dynamic>{'designId': '100k-12345', 'tank_L': 1000},
        fileName: '100k-12345',
      ),
    );

    expect(cadAdapter.lastOptions?.method, 'POST');
    expect(cadAdapter.lastOptions?.path, '/cad/run-3d-generation');
    expect(cadAdapter.lastOptions?.queryParameters, <String, dynamic>{
      'fileName': '100k-12345',
      'skipBatRun': 'no',
    });
    expect(cadAdapter.lastDecodedBody, <String, dynamic>{
      'designId': '100k-12345',
      'tank_L': 1000,
    });
    expect(response.message, 'fabrication generation requested');
  });

  test('loadModel requests the glb blob from storage with skip-auth', () async {
    storageAdapter.nextResponseBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final response = await cadRepository.loadModel('100k-12345');

    expect(storageAdapter.lastOptions?.method, 'GET');
    expect(storageAdapter.lastOptions?.path, '/models/100k-12345.glb');
    expect(storageAdapter.lastOptions?.headers['X-Skip-Auth'], true);
    expect(response.bytes, Uint8List.fromList(<int>[1, 2, 3, 4]));
  });

  test(
    'fetchStatuses posts the designId filter to drawingsStatus list',
    () async {
      commonAdapter.nextResponseJson = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'status-1',
            'designId': '100k-12345',
            'message': 'Generate 3D Requested',
            'status': 'Success',
            'createdAt': '2026-07-16T09:00:00.000Z',
          },
        ],
        'total': 1,
      };

      final response = await drawingsStatusRepository.fetchStatuses(
        designId: '100k-12345',
      );

      expect(commonAdapter.lastOptions?.method, 'POST');
      expect(commonAdapter.lastOptions?.path, '/entity/v2/drawingsStatus');
      expect(commonAdapter.lastOptions?.queryParameters, <String, dynamic>{
        'offset': 0,
        'size': 30,
      });
      expect(commonAdapter.lastDecodedBody, <String, dynamic>{
        'designId': <String>['100k-12345'],
      });
      expect(response.total, 1);
      expect(response.data.single.message, 'Generate 3D Requested');
    },
  );

  test('createStatus uses the drawingsStatus entity create path', () async {
    commonAdapter.nextResponseJson = const <String, dynamic>{};

    await drawingsStatusRepository.createStatus(
      const DrawingsStatusCreateRequest(
        designId: '100k-12345',
        message: 'Generate 3D Requested',
        status: 'Success',
      ),
    );

    expect(commonAdapter.lastOptions?.method, 'PUT');
    expect(commonAdapter.lastOptions?.path, '/entity/drawingsStatus');
    expect(commonAdapter.lastDecodedBody, <String, dynamic>{
      'designId': '100k-12345',
      'message': 'Generate 3D Requested',
      'status': 'Success',
    });
  });

  test('deleteStatus uses the documented entity delete endpoint', () async {
    commonAdapter.nextResponseJson = const <String, dynamic>{};

    await drawingsStatusRepository.deleteStatus('status-9');

    expect(commonAdapter.lastOptions?.method, 'DELETE');
    expect(commonAdapter.lastOptions?.path, '/entity/drawingsStatus/status-9');
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
  Uint8List? nextResponseBytes;

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

    if (options.responseType == ResponseType.bytes) {
      return ResponseBody.fromBytes(
        nextResponseBytes ?? Uint8List(0),
        200,
        headers: const <String, List<String>>{
          'content-type': <String>['model/gltf-binary'],
        },
      );
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
