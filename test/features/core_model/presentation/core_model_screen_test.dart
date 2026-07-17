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
import 'package:trafo_desktop/src/features/core_model/presentation/core_model_screen.dart';
import 'package:trafo_desktop/src/features/home/application/home_controller.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/home/domain/repositories/design_repository.dart';

void main() {
  testWidgets('core screen renders persisted metrics and editor state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        const DesignSummary(
          id: 'entity-1',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","core":{"coreDia":210,"limbHt":640,"cenDist":420},"lvFormulas":{"revisedFluxDensity":1.652}}',
          core:
              '{"coreArea":1234,"coreWeight":456,"designedCoreArea":1111,"bldStacks":[{"stepNo":1,"width":120,"stack":90},{"stepNo":2,"width":80,"stack":45}]}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Core Model'), findsOneWidget);
    expect(find.text('Reference: 100k-12345'), findsOneWidget);
    expect(find.text('Gross Core Area'), findsOneWidget);
    expect(find.text('1234 sqmm'), findsOneWidget);
    expect(find.text('Selected Step'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('core-narrow-field-Width-120')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('core-step-row-2')),
      findsOneWidget,
    );
  });

  testWidgets('print preview opens from the core screen', (tester) async {
    await tester.pumpWidget(
      _buildScreen(
        const DesignSummary(
          id: 'entity-1',
          designId: '100k-12345',
          twoWindings:
              '{"designId":"100k-12345","core":{"coreDia":210,"limbHt":640,"cenDist":420},"lvFormulas":{"revisedFluxDensity":1.652}}',
          core:
              '{"coreArea":1234,"coreWeight":456,"designedCoreArea":1111,"bldStacks":[{"stepNo":1,"width":120,"stack":90},{"stepNo":2,"width":80,"stack":45}]}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Print Preview'));
    await tester.tap(find.text('Print Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Core Print Preview'), findsOneWidget);
    expect(find.text('Stacking'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}

Widget _buildScreen(DesignSummary summary) {
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

  return AppScope(
    dependencies: AppDependencies(
      environment: environment,
      apiClient: apiClient,
      tokenStorage: tokenStorage,
      authController: authController,
      homeController: homeController,
    ),
    child: MaterialApp(
      home: Scaffold(
        body: CoreModelScreen(
          routeDesignId: summary.id,
          initialDesignSummary: summary,
        ),
      ),
    ),
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
    return const OtpDispatchResult(issued: true, sessionInfo: '');
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
