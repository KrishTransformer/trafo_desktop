import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/users/data/repositories/http_users_repository.dart';
import 'package:trafo_desktop/src/features/users/domain/models/user_draft.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpUsersRepository repository;

  setUp(() {
    adapter = _RecordingAdapter();

    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;
    repository = HttpUsersRepository(apiClient);
  });

  test('fetchUsers posts to the users entity list path', () async {
    adapter.nextResponseJson = <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'user-1',
          'name': 'Krish',
          'email': 'krish@example.com',
        },
      ],
      'total': 1,
    };

    final response = await repository.fetchUsers(
      const EntityListQuery(
        offset: 0,
        size: 10,
        sortAttribute: 'createdAt',
        sortOrder: 'ASC',
      ),
    );

    expect(adapter.lastOptions?.method, 'POST');
    expect(adapter.lastOptions?.path, '/entity/v2/users');
    expect(response.total, 1);
    expect(response.data.single.email, 'krish@example.com');
  });

  test('createUser uses the entity create path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.createUser(
      const UserDraft(name: 'Krish', email: 'krish@example.com'),
    );

    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.path, '/entity/users');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'name': 'Krish',
      'email': 'krish@example.com',
    });
  });

  test('updateUser uses the entity update path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.updateUser(
      entityId: 'user-1',
      user: const UserDraft(name: 'Krish T', email: 'kt@example.com'),
    );

    expect(adapter.lastOptions?.method, 'PUT');
    expect(adapter.lastOptions?.path, '/entity/users/user-1');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'name': 'Krish T',
      'email': 'kt@example.com',
    });
  });

  test('deleteUser uses the entity delete path', () async {
    adapter.nextResponseJson = const <String, dynamic>{};

    await repository.deleteUser('user-7');

    expect(adapter.lastOptions?.method, 'DELETE');
    expect(adapter.lastOptions?.path, '/entity/users/user-7');
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
