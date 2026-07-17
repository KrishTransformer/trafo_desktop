import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/app/app.dart';
import 'package:trafo_desktop/src/app/router/app_router.dart';
import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
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
import 'package:trafo_desktop/src/features/home/application/home_controller.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/home/domain/repositories/design_repository.dart';

void main() {
  final environment = AppEnvironment(
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

  testWidgets('unauthenticated users are redirected to sign in', (
    tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage();
    final app = await _buildApp(environment, tokenStorage);

    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsWidgets);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('authenticated users land on home without the desktop rail', (
    tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage()..token = 'stored-token';
    final app = await _buildApp(environment, tokenStorage);

    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Krish Transformer Design Software'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('Trafo Desktop'), findsNothing);
  });
}

Future<TrafoDesktopApp> _buildApp(
  AppEnvironment environment,
  _InMemoryTokenStorage tokenStorage,
) async {
  final apiClient = ApiClient(
    environment: environment,
    tokenStorage: tokenStorage,
  );
  final authController = AuthController(
    authRepository: _FakeAuthRepository(),
    configRepository: _FakeConfigRepository(),
    tokenStorage: tokenStorage,
  );
  final homeController = HomeController(
    designRepository: _FakeDesignRepository(),
    tokenStorage: tokenStorage,
  );
  await authController.initialize();

  return TrafoDesktopApp(
    environment: environment,
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    authController: authController,
    homeController: homeController,
    router: AppRouter(
      environment: environment,
      authController: authController,
    ).router,
  );
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
    return const OtpDispatchResult(issued: true, sessionInfo: 'session-1');
  }

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    return const AuthSession(
      idToken: 'id-token',
      refreshToken: '',
      roles: <String>[],
      entityId: '',
      email: '',
    );
  }

  @override
  Future<void> signUp(SignUpRequest request) async {}
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

class _FakeDesignRepository implements DesignRepository {
  @override
  Future<void> deleteDesign(String designId) async {}

  @override
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(
    DesignListQuery query,
  ) async {
    return const PaginatedResponse<DesignSummary>(
      data: <DesignSummary>[],
      total: 0,
    );
  }

  @override
  Future<PaginatedResponse<DesignSummary>> searchDesigns({
    required DesignListQuery query,
    required DesignSearchRequest request,
  }) async {
    return const PaginatedResponse<DesignSummary>(
      data: <DesignSummary>[],
      total: 0,
    );
  }
}
