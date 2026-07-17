import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:trafo_desktop/src/app/app_scope.dart';
import 'package:trafo_desktop/src/app/router/route_paths.dart';
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
import 'package:trafo_desktop/src/features/authentication/presentation/forgot_password_screen.dart';
import 'package:trafo_desktop/src/features/authentication/presentation/login_screen.dart';
import 'package:trafo_desktop/src/features/home/application/home_controller.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/home/domain/repositories/design_repository.dart';

void main() {
  testWidgets('login screen validates empty credentials locally', (
    tester,
  ) async {
    final controller = await _buildController();

    await tester.pumpWidget(_wrapAuthScreen(controller, const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In').last);
    await tester.pumpAndSettle();

    expect(find.text('Please fill out all fields.'), findsOneWidget);
  });

  testWidgets('forgot password screen reveals OTP fields after sending OTP', (
    tester,
  ) async {
    final controller = await _buildController();

    await tester.pumpWidget(
      _wrapAuthScreen(controller, const ForgotPasswordScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('OTP sent to the registered email'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
  });
}

Future<AuthController> _buildController() async {
  final controller = AuthController(
    authRepository: _FakeAuthRepository(),
    configRepository: _FakeConfigRepository(),
    tokenStorage: _InMemoryTokenStorage(),
  );
  await controller.initialize();
  return controller;
}

Widget _wrapAuthScreen(AuthController controller, Widget child) {
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
  final tokenStorage = _InMemoryTokenStorage();
  final apiClient = ApiClient(
    environment: environment,
    tokenStorage: tokenStorage,
  );
  final homeController = HomeController(
    designRepository: _FakeDesignRepository(),
    tokenStorage: tokenStorage,
  );
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: RoutePaths.login, builder: (_, _) => child),
      GoRoute(path: RoutePaths.signUp, builder: (_, _) => const SizedBox()),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: RoutePaths.home, builder: (_, _) => const SizedBox()),
    ],
  );

  return AppScope(
    dependencies: AppDependencies(
      environment: environment,
      apiClient: apiClient,
      tokenStorage: tokenStorage,
      authController: controller,
      homeController: homeController,
    ),
    child: MaterialApp.router(routerConfig: router),
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
