import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/authentication/application/auth_controller.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/auth_session.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/forgot_password_request.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/otp_dispatch_result.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/sign_in_request.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/sign_up_request.dart';
import 'package:trafo_desktop/src/features/authentication/domain/models/tenant_config.dart';
import 'package:trafo_desktop/src/features/authentication/domain/repositories/auth_repository.dart';
import 'package:trafo_desktop/src/features/authentication/domain/repositories/config_repository.dart';

void main() {
  test(
    'initialize marks the controller authenticated when a token exists',
    () async {
      final tokenStorage = _InMemoryTokenStorage()..token = 'stored-token';
      final controller = AuthController(
        authRepository: _FakeAuthRepository(),
        configRepository: _FakeConfigRepository(),
        tokenStorage: tokenStorage,
      );

      await controller.initialize();

      expect(controller.state.isReady, isTrue);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.tenantName, 'Krish');
    },
  );

  test('signIn stores tokens and authenticates the session', () async {
    final tokenStorage = _InMemoryTokenStorage();
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      configRepository: _FakeConfigRepository(),
      tokenStorage: tokenStorage,
    );
    await controller.initialize();

    final success = await controller.signIn(
      const SignInRequest(
        usernameOrEmail: 'user@example.com',
        password: 'secret123',
      ),
    );

    expect(success, isTrue);
    expect(controller.state.isAuthenticated, isTrue);
    expect(tokenStorage.token, 'id-token');
    expect(tokenStorage.refreshToken, 'refresh-token');
  });

  test('signIn maps backend auth failures to user-facing messages', () async {
    final tokenStorage = _InMemoryTokenStorage();
    final controller = AuthController(
      authRepository: _FailingAuthRepository(),
      configRepository: _FakeConfigRepository(),
      tokenStorage: tokenStorage,
    );
    await controller.initialize();

    final success = await controller.signIn(
      const SignInRequest(
        usernameOrEmail: 'user@example.com',
        password: 'bad-pass',
      ),
    );

    expect(success, isFalse);
    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.errorMessage, 'Invalid Username or Password');
  });

  test('handleUnauthorized clears tokens and sets redirect message', () async {
    final tokenStorage = _InMemoryTokenStorage()
      ..token = 'id-token'
      ..refreshToken = 'refresh-token';
    final controller = AuthController(
      authRepository: _FakeAuthRepository(),
      configRepository: _FakeConfigRepository(),
      tokenStorage: tokenStorage,
    );
    await controller.initialize();

    await controller.handleUnauthorized();

    expect(controller.state.isAuthenticated, isFalse);
    expect(
      controller.state.redirectMessage,
      'Session expired. Please log in again.',
    );
    expect(tokenStorage.token, isNull);
    expect(tokenStorage.refreshToken, isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}

  @override
  Future<void> resetPasswordByEmail(ForgotPasswordRequest request) async {}

  @override
  Future<OtpDispatchResult> sendEmailOtp(String email) async {
    return const OtpDispatchResult(issued: true, sessionInfo: '');
  }

  @override
  Future<OtpDispatchResult> sendForgotPasswordOtp(String email) async {
    return const OtpDispatchResult(issued: true, sessionInfo: 'session');
  }

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    return const AuthSession(
      idToken: 'id-token',
      refreshToken: 'refresh-token',
      roles: <String>['ROLE_USER'],
      entityId: 'entity-1',
      email: 'user@example.com',
    );
  }

  @override
  Future<void> signUp(SignUpRequest request) async {}
}

class _FailingAuthRepository extends _FakeAuthRepository {
  @override
  Future<AuthSession> signIn(SignInRequest request) {
    throw const ApiException(
      type: ApiExceptionType.unauthorized,
      message: 'The server returned an unexpected response.',
      statusCode: 401,
      responseData: <String, dynamic>{'error': 'INVALID_PASSWORD'},
    );
  }
}

class _FakeConfigRepository implements ConfigRepository {
  @override
  Future<TenantConfig> fetchConfig() async {
    return const TenantConfig(tenantName: 'Krish');
  }
}

class _InMemoryTokenStorage implements TokenStorage {
  String? token;
  String? refreshToken;

  @override
  Future<void> clear() async {
    token = null;
    refreshToken = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    refreshToken = token;
  }
}
