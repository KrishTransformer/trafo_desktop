import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/app/app_scope.dart';
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
import 'package:trafo_desktop/src/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home screen renders loaded designs in a constrained viewport', (
    tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage();
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

    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies(
          environment: environment,
          apiClient: apiClient,
          tokenStorage: tokenStorage,
          authController: authController,
          homeController: homeController,
        ),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 960, height: 540, child: HomeScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('DES-0001'), findsOneWidget);
    expect(find.text('DES-0020'), findsOneWidget);
  });

  testWidgets('new design dialog offers both two- and multi-winding flows', (
    tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage();
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

    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies(
          environment: environment,
          apiClient: apiClient,
          tokenStorage: tokenStorage,
          authController: authController,
          homeController: homeController,
        ),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 960, height: 540, child: HomeScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Design'));
    await tester.pumpAndSettle();

    expect(find.text('Open 2 Winding'), findsOneWidget);
    expect(find.text('Open Multi Winding'), findsOneWidget);
  });
}

class _FakeDesignRepository implements DesignRepository {
  @override
  Future<void> deleteDesign(String designId) async {}

  @override
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(
    DesignListQuery query,
  ) async {
    return PaginatedResponse<DesignSummary>(
      data: List<DesignSummary>.generate(20, (index) {
        final itemNumber = index + 1;
        return DesignSummary(
          id: 'entity-$itemNumber',
          designId: 'DES-${itemNumber.toString().padLeft(4, '0')}',
          twoWindings:
              '{"kVA":100,"lowVoltage":433,"highVoltage":11000,"ez":4.5,"voltsPerTurn":3.21,"coreLoss":123,"loadLoss":456,"cost":{"capitalCost":7890},"core":{"coreDia":210,"limbHt":640,"cenDist":420}}',
          createdAt: '2026-07-15T08:00:00.000Z',
          updatedAt: '2026-07-15T10:00:00.000Z',
        );
      }),
      total: 20,
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
      idToken: 'token',
      refreshToken: '',
      roles: <String>[],
      entityId: '',
      email: 'demo@example.com',
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
