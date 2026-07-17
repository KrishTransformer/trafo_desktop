import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/authentication/data/repositories/http_auth_repository.dart';
import 'package:trafo_desktop/src/features/authentication/data/repositories/http_config_repository.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/forgot_password_request.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/sign_in_request.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/sign_up_request.dart';

void main() {
  late _RecordingAdapter adapter;
  late HttpAuthRepository authRepository;
  late HttpConfigRepository configRepository;

  setUp(() {
    adapter = _RecordingAdapter();
    final apiClient = ApiClient(
      environment: _testEnvironment,
      tokenStorage: _FakeTokenStorage(),
    );
    apiClient.clientFor(ApiService.common).httpClientAdapter = adapter;

    authRepository = HttpAuthRepository(apiClient);
    configRepository = HttpConfigRepository(apiClient);
  });

  test(
    'signIn sends the expected JSON payload and Basic auth header',
    () async {
      adapter.nextResponseJson = <String, dynamic>{
        'idToken': 'id-token',
        'refreshToken': 'refresh-token',
        'roles': <String>['ROLE_USER'],
        'entityId': 'entity-1',
        'email': 'demo@example.com',
      };

      final session = await authRepository.signIn(
        const SignInRequest(
          usernameOrEmail: 'demo@example.com',
          password: 'secret123',
        ),
      );

      expect(adapter.lastOptions?.path, '/auth/signin');
      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastDecodedBody, <String, dynamic>{
        'usernameOrEmail': 'demo@example.com',
        'password': 'secret123',
        'email': 'demo@example.com',
      });
      expect(
        adapter.lastOptions?.headers['Authorization'],
        startsWith('Basic '),
      );
      expect(session.idToken, 'id-token');
      expect(session.refreshToken, 'refresh-token');
    },
  );

  test('signUp preserves request field names exactly', () async {
    adapter.nextResponseJson = <String, dynamic>{'status': 'ok'};

    await authRepository.signUp(
      const SignUpRequest(
        username: 'krish',
        password: 'secret123',
        email: 'krish@example.com',
        otp: '123456',
      ),
    );

    expect(adapter.lastOptions?.path, '/auth/signup');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'username': 'krish',
      'password': 'secret123',
      'email': 'krish@example.com',
      'otp': '123456',
    });
    expect(adapter.lastOptions?.headers.containsKey('X-Skip-Auth'), isFalse);
    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });

  test('resetPasswordByEmail sends the expected payload', () async {
    adapter.nextResponseJson = <String, dynamic>{'status': 'ok'};

    await authRepository.resetPasswordByEmail(
      const ForgotPasswordRequest(
        email: 'user@example.com',
        otp: '654321',
        newPassword: 'newSecret',
      ),
    );

    expect(adapter.lastOptions?.path, '/auth/passwordResetByEmail');
    expect(adapter.lastDecodedBody, <String, dynamic>{
      'email': 'user@example.com',
      'otp': '654321',
      'newPassword': 'newSecret',
    });
  });

  test('config repository parses tenantName from /config', () async {
    adapter.nextResponseJson = <String, dynamic>{'tenantName': 'Krish'};

    final config = await configRepository.fetchConfig();

    expect(adapter.lastOptions?.path, '/config');
    expect(config.tenantName, 'Krish');
  });

  test('config repository tolerates unexpected non-map payloads', () async {
    adapter.nextResponseJson = const <String, dynamic>{};
    adapter.nextResponseBody = '"ok"';

    final config = await configRepository.fetchConfig();

    expect(adapter.lastOptions?.path, '/config');
    expect(config.tenantName, isEmpty);
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

    if (requestBytes.isEmpty) {
      lastDecodedBody = null;
    } else {
      lastDecodedBody = jsonDecode(utf8.decode(requestBytes)) as Object?;
    }

    return ResponseBody.fromString(
      nextResponseBody ?? jsonEncode(nextResponseJson),
      200,
      headers: const <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
