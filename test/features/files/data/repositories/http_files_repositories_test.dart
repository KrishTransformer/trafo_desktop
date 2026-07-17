import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/files/data/repositories/http_files_design_repository.dart';
import 'package:trafo_desktop/src/features/files/data/repositories/http_files_lom_repository.dart';
import 'package:trafo_desktop/src/features/files/data/repositories/http_lom_material_repository.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_line_item.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_request.dart';

void main() {
  late _RecordingAdapter commonAdapter;
  late _RecordingAdapter coreAdapter;
  late HttpFilesLomRepository lomRepository;
  late HttpFilesDesignRepository designRepository;
  late HttpLomMaterialRepository lomMaterialRepository;

  setUp(() {
    commonAdapter = _RecordingAdapter();
    coreAdapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = commonAdapter;
    apiClient.clientFor(ApiService.core).httpClientAdapter = coreAdapter;

    lomRepository = HttpFilesLomRepository(apiClient);
    designRepository = HttpFilesDesignRepository(apiClient);
    lomMaterialRepository = HttpLomMaterialRepository(apiClient);
  });

  test(
    'generateLom posts the documented files payload and preserves normalized keys',
    () async {
      coreAdapter.nextResponseBody = <Map<String, dynamic>>[
        <String, dynamic>{
          'description': 'Lamination',
          'specification': 'CRGO',
          'unit': 'kg',
          'quantity': 125.5,
          'rate': 220,
          'cost': 27610,
        },
      ];

      final response = await lomRepository.generateLom(
        LomRequest(
          lomBooleans: <String, bool>{
            'hvCableBox': false,
            'biMetallicConn': true,
            'fasteners': true,
            'unknownFlag': true,
          },
          lomQuantity: <String, num>{
            'lamination': 125.5,
            'biMetallicConnector': 0,
            'otherMaterials': 0,
            'ignoredQuantity': 99,
          },
          lomRate: <String, num>{
            'hvCableBox': 7000,
            'biMetallicConnector': 800,
            'fasteners': 42,
            'otherMaterials': 0,
            'ignoredRate': 999,
          },
        ),
      );

      expect(coreAdapter.lastOptions?.method, 'POST');
      expect(coreAdapter.lastOptions?.path, '/files/lom');
      expect(coreAdapter.lastDecodedBody, <String, dynamic>{
        'isTrue': true,
        'lomBooleans': <String, dynamic>{
          'hvCableBox': false,
          'biMetallicConnector': true,
          'fasteners': true,
        },
        'lomQuantity': <String, dynamic>{
          'lamination': 125.5,
          'biMetallicConnector': 0,
          'otherMaterials': 0,
        },
        'lomRate': <String, dynamic>{
          'biMetallicConnector': 800,
          'fasteners': 42,
          'otherMaterials': 0,
        },
      });
      expect(response.single.description, 'Lamination');
      expect(response.single.quantity, 125.5);
      expect(response.single.rate, 220);
    },
  );

  test(
    'fetchMaterials posts to the documented lomMaterial entity list',
    () async {
      commonAdapter.nextResponseBody = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'lom-1',
            'materialName': 'Lamination',
            'materialRate': 220.0,
          },
          <String, dynamic>{
            'id': 'lom-2',
            'materialName': 'HV Conductor',
            'materialRate': 125.0,
          },
        ],
        'total': 2,
      };

      final response = await lomMaterialRepository.fetchMaterials(
        const EntityListQuery(
          offset: 0,
          size: 100,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );

      expect(commonAdapter.lastOptions?.method, 'POST');
      expect(commonAdapter.lastOptions?.path, '/entity/v2/lomMaterial');
      expect(commonAdapter.lastOptions?.queryParameters, <String, dynamic>{
        'offset': 0,
        'size': 100,
        'sortAttribute': 'createdAt',
        'sortOrder': 'ASC',
      });
      expect(commonAdapter.lastDecodedBody, <String, dynamic>{});
      expect(response.total, 2);
      expect(response.data.first.materialName, 'Lamination');
      expect(response.data.first.materialRate, 220.0);
      expect(response.data.last.id, 'lom-2');
    },
  );

  test(
    'persistLom updates the existing design entity with serialized lom JSON',
    () async {
      commonAdapter.nextResponseBody = const <String, dynamic>{};

      await designRepository.persistLom(
        entityId: 'entity-15',
        items: <LomLineItem>[
          LomLineItem.fromJson(<String, dynamic>{
            'description': 'Other Materials',
            'specification': 'Custom',
            'unit': 'lot',
            'quantity': 1,
            'rate': 900,
            'cost': 900,
            'index': 39,
            'isNew': true,
            'rateKey': null,
          }),
        ],
      );

      final requestBody = commonAdapter.lastDecodedBody!;
      expect(commonAdapter.lastOptions?.method, 'PUT');
      expect(commonAdapter.lastOptions?.path, '/entity/design/entity-15');
      expect(requestBody.keys, <String>['lom']);
      expect(jsonDecode(requestBody['lom'] as String), <Map<String, dynamic>>[
        <String, dynamic>{
          'description': 'Other Materials',
          'specification': 'Custom',
          'unit': 'lot',
          'quantity': 1,
          'rate': 900,
          'cost': 900,
          'index': 39,
          'isNew': true,
          'rateKey': null,
        },
      ]);
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
  Object? nextResponseBody = const <String, dynamic>{};

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
      jsonEncode(nextResponseBody),
      200,
      headers: const <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
