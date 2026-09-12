import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:trafo_desktop/src/app/app_scope.dart';
import 'package:trafo_desktop/src/app/router/app_router.dart';
import 'package:trafo_desktop/src/app/router/route_paths.dart';
import 'package:trafo_desktop/src/core/config/app_environment.dart';
import 'package:trafo_desktop/src/core/network/api_client.dart';
import 'package:trafo_desktop/src/core/network/api_service.dart';
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
import 'package:trafo_desktop/src/features/design_workspace/presentation/two_winding_screen.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';
import 'package:trafo_desktop/src/features/home/application/home_controller.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/home/domain/repositories/design_repository.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1366, 768),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final design = TwoWindingDesign.initial()
        .copyWithPath('tank.tankLength', '1200')
        .copyWithPath('tank.tankDimension', '1200 x 700 x 1500')
        .copyWithPath('tank.overallDimension', '1400 x 900 x 1800')
        .copyWithPath('innerWindings.condInsulation', '0.25')
        .copyWithPath('core.coreWeight', '350')
        .copyWithPath('cost.totalCoreCost', '70000');
    await tester.pumpWidget(
      _buildScreen(
        DesignSummary(
          id: 'saved-design',
          designId: '',
          twoWindings: design.toJson(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder input(String label) => find.descendant(
    of: find.byKey(ValueKey(label)),
    matching: find.byType(TextFormField),
  );

  testWidgets(
    'choosing New Design clears both retained drafts and saved designs',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppDependencies dependencies;
      late GoRouter router;
      final app = _buildScreen(
        const DesignSummary(id: 'unused', designId: ''),
        appBuilder: (value) {
          dependencies = value;
          router = AppRouter(
            environment: value.environment,
            authController: value.authController,
          ).router;
          addTearDown(router.dispose);
          return MaterialApp.router(routerConfig: router);
        },
      );
      await dependencies.authController.signIn(
        const SignInRequest(
          usernameOrEmail: 'test@example.com',
          password: 'test',
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      Future<void> chooseNew() async {
        await tester.tap(find.text('New Design'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open 2 Winding'));
        await tester.pumpAndSettle();
      }

      await chooseNew();
      for (final fromSaved in [false, true]) {
        if (fromSaved) {
          router.go(
            RoutePaths.twoWindingsDesign('saved-1'),
            extra: DesignSummary(
              id: 'saved-1',
              designId: '500k-12345',
              twoWindings: TwoWindingDesign.initial()
                  .copyWithPath('kVA', '500')
                  .copyWithPath('tank.tankLength', '1200')
                  .toJson(),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(input('kVA')).controller!.text,
            '500',
          );
          expect(
            tester.widget<TextFormField>(input('Tank Length')).controller!.text,
            '1200',
          );
        }
        await tester.enterText(input('kVA'), '250');
        await tester.pumpAndSettle();
        final lock = find.descendant(
          of: find.byKey(const ValueKey('Core Diameter')),
          matching: find.byType(IconButton),
        );
        await tester.ensureVisible(lock);
        await tester.tap(lock);
        await tester.ensureVisible(find.text('More Info'));
        await tester.tap(find.text('More Info'));
        await tester.pumpAndSettle();
        router.go(RoutePaths.home);
        await tester.pumpAndSettle();
        await chooseNew();

        for (final label in [
          'kVA',
          'Core Diameter',
          'Flux Density',
          'Tank Length',
          'Load Loss',
        ]) {
          expect(
            tester.widget<TextFormField>(input(label)).controller!.text,
            isEmpty,
            reason: label,
          );
        }
        expect(
          tester.widget<TextFormField>(input('Frequency')).controller!.text,
          '50',
        );
        expect(find.text('Tank & Cooling'), findsNothing);
        expect(find.text('Open Core'), findsNothing);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: input('Core Diameter'),
                  matching: find.byType(TextField),
                ),
              )
              .readOnly,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('choosing New Multi Winding starts a fresh MWdg draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppDependencies dependencies;
    late GoRouter router;
    final app = _buildScreen(
      const DesignSummary(id: 'unused', designId: ''),
      appBuilder: (value) {
        dependencies = value;
        router = AppRouter(
          environment: value.environment,
          authController: value.authController,
        ).router;
        addTearDown(router.dispose);
        return MaterialApp.router(routerConfig: router);
      },
    );
    await dependencies.authController.signIn(
      const SignInRequest(
        usernameOrEmail: 'test@example.com',
        password: 'test',
      ),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    Finder multiInput(String label) =>
        find.widgetWithText(TextFormField, label);
    String multiInputText(String label) => tester
        .widget<EditableText>(
          find.descendant(
            of: multiInput(label),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;

    Future<void> chooseNewMulti() async {
      await tester.tap(find.text('New Design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Multi Winding'));
      await tester.pumpAndSettle();
    }

    await chooseNewMulti();
    expect(multiInputText('kVA'), '');
    expect(multiInputText('Frequency'), '50');
    expect(find.text('Transformer Inputs'), findsOneWidget);
    expect(find.text('Core Details'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tank Details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tank Details'), findsOneWidget);
    expect(find.text('Cooling Details'), findsOneWidget);

    await tester.tap(find.text('Windings'));
    await tester.pumpAndSettle();
    expect(find.text('Winding Details'), findsOneWidget);
    expect(find.text('No. of Turns'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Dimensions & Cost'));
    await tester.pumpAndSettle();
    expect(find.text('Coil Winding Dimensions'), findsOneWidget);
    expect(find.text('Cost Estimations'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Inputs'));
    await tester.pumpAndSettle();
    await tester.enterText(multiInput('kVA'), '25000');
    await tester.pumpAndSettle();
    expect(find.text('Outer'), findsWidgets);
    await tester.tap(find.text('Windings'));
    await tester.pumpAndSettle();
    expect(find.text('Corse'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    expect(find.text('Outer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go(RoutePaths.home);
    await tester.pumpAndSettle();
    await chooseNewMulti();

    expect(multiInputText('kVA'), '');
    expect(multiInputText('Frequency'), '50');
    expect(tester.takeException(), isNull);
  });

  for (final width in [1366.0, 1100.0, 800.0, 600.0]) {
    testWidgets('reference layout and tabs fit at width $width', (
      tester,
    ) async {
      await open(tester, size: Size(width, 768));
      expect(find.text('Calculate'), findsOneWidget);
      expect(find.text('Tank Details'), findsOneWidget);
      expect(find.text('Inner Winding LV'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('More Info'));
      await tester.tap(find.text('More Info'));
      await tester.pumpAndSettle();
      expect(find.text('1200 x 700 x 1500'), findsOneWidget);
      expect(find.text('1400 x 900 x 1800'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final tab in ['Coil Dimensions', 'Costings']) {
        await tester.ensureVisible(find.text(tab));
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('70000'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
    });
  }

  testWidgets('typing preserves focus and reset restores displayed values', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(input('kVA'));
    await tester.enterText(input('kVA'), '1');
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '100',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(tester.widget<TextFormField>(input('kVA')).controller!.text, '100');
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(
      tester.widget<TextFormField>(input('Flux Density')).controller!.text,
      '1.7333',
    );
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(input('kVA')).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(input('Tank Length')).controller!.text,
      '1200',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('core lock is reversible and dry type updates visible sections', (
    tester,
  ) async {
    await open(tester);
    final lock = find.descendant(
      of: find.byKey(const ValueKey('Core Diameter')),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(lock);
    await tester.tap(lock);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: input('Core Diameter'),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.tap(lock);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: input('Core Diameter'),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isFalse,
    );
    final insulation = find.byKey(
      const ValueKey('dropdown-Insulation Type-Oil Type'),
    );
    await tester.ensureVisible(insulation);
    await tester.tap(insulation);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dry Type').last);
    await tester.pumpAndSettle();
    expect(find.text('Dry Temp Class'), findsOneWidget);
    expect(find.text('Enclosure Details'), findsOneWidget);
    expect(find.text('Tank Capacity'), findsNothing);
    await tester.ensureVisible(find.text('More Info'));
    await tester.tap(find.text('More Info'));
    await tester.pumpAndSettle();
    expect(find.text('Enclosure & Temp'), findsOneWidget);
    expect(find.text('Oil Temp'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calculate sends the 2Wdg payload and applies returned values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final commonAdapter = _RecordingAdapter()
      ..nextResponseJson = <String, dynamic>{'id': 'saved-200'};
    final coreAdapter = _RecordingAdapter()
      ..nextResponseJson = TwoWindingDesign.initial()
          .copyWithPath('kVA', '200')
          .copyWithPath('core.coreDia', '321')
          .copyWithPath('core.limbHt', '654')
          .copyWithPath('tank.tankLength', '1200')
          .toJson();

    await tester.pumpWidget(
      _buildScreen(
        const DesignSummary(id: 'new', designId: ''),
        commonAdapter: commonAdapter,
        coreAdapter: coreAdapter,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(input('kVA'), '200');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    expect(coreAdapter.lastOptions?.method, 'POST');
    expect(coreAdapter.lastOptions?.path, '/calculate/2windings/circular');
    expect(coreAdapter.lastOptions?.headers['User-Calc'].toString(), 'true');

    final calculationPayload = coreAdapter.lastDecodedBody!;
    expect(calculationPayload['kVA'], '200');
    expect(calculationPayload['lowVoltage'], 433);
    expect(calculationPayload['highVoltage'], 11000);
    expect(calculationPayload['frequency'], '50');
    expect(calculationPayload['tapStepsPercent'], isNull);
    expect(calculationPayload['dryTempClass'], isNull);
    expect(calculationPayload['core']['coreDia'], isNull);
    expect(calculationPayload['core']['cenDist'], isNull);
    expect(calculationPayload['innerWindings']['turnsPerPhase'], isNull);
    expect(calculationPayload['innerWindings']['terminal'], isNull);
    expect(calculationPayload['outerWindings']['turnsPerPhase'], isNull);
    expect(calculationPayload['outerWindings']['terminal'], isNull);

    expect(commonAdapter.lastOptions?.method, 'PUT');
    expect(commonAdapter.lastOptions?.path, '/entity/design');
    expect(commonAdapter.lastDecodedBody?['designType'], 'two');
    expect(commonAdapter.lastDecodedBody?['designId'], startsWith('200k-'));

    final persisted =
        jsonDecode(commonAdapter.lastDecodedBody?['twoWindings'] as String)
            as Map<String, dynamic>;
    expect(persisted['designId'], startsWith('200k-'));
    expect((persisted['core'] as Map<String, dynamic>)['coreDia'], '321');

    expect(
      tester.widget<TextFormField>(input('Core Diameter')).controller!.text,
      '321',
    );
    expect(find.text('Open Core'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildScreen(
  DesignSummary summary, {
  Widget Function(AppDependencies)? appBuilder,
  HttpClientAdapter? commonAdapter,
  HttpClientAdapter? coreAdapter,
}) {
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
  if (commonAdapter != null) {
    apiClient.clientFor(ApiService.common).httpClientAdapter = commonAdapter;
  }
  if (coreAdapter != null) {
    apiClient.clientFor(ApiService.core).httpClientAdapter = coreAdapter;
  }
  final authController = AuthController(
    authRepository: _FakeAuthRepository(),
    configRepository: _FakeConfigRepository(),
    tokenStorage: tokenStorage,
  );
  final homeController = HomeController(
    designRepository: _FakeDesignRepository(),
    tokenStorage: tokenStorage,
  );

  addTearDown(authController.dispose);
  addTearDown(homeController.dispose);
  final dependencies = AppDependencies(
    environment: environment,
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    authController: authController,
    homeController: homeController,
  );
  return AppScope(
    dependencies: dependencies,
    child:
        appBuilder?.call(dependencies) ??
        MaterialApp(
          home: Scaffold(
            body: TwoWindingScreen(
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

    if (requestBytes.isEmpty) {
      lastDecodedBody = null;
    } else {
      lastDecodedBody =
          jsonDecode(utf8.decode(requestBytes)) as Map<String, dynamic>;
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
