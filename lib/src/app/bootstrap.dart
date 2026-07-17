import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_environment.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_token_storage.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/authentication/data/repositories/http_auth_repository.dart';
import '../features/authentication/data/repositories/http_config_repository.dart';
import '../features/home/application/home_controller.dart';
import '../features/home/data/repositories/http_design_repository.dart';
import 'app.dart';
import 'router/app_router.dart';

Future<TrafoDesktopApp> bootstrap() async {
  final environment = AppEnvironment.fromDefines();
  final tokenStorage = SecureTokenStorage(const FlutterSecureStorage());
  late final AuthController authController;
  final apiClient = ApiClient(
    environment: environment,
    tokenStorage: tokenStorage,
    onUnauthorized: () async => authController.handleUnauthorized(),
  );
  final authRepository = HttpAuthRepository(apiClient);
  final configRepository = HttpConfigRepository(apiClient);
  final designRepository = HttpDesignRepository(apiClient);
  authController = AuthController(
    authRepository: authRepository,
    configRepository: configRepository,
    tokenStorage: tokenStorage,
  );
  final homeController = HomeController(
    designRepository: designRepository,
    tokenStorage: tokenStorage,
  );
  await authController.initialize();
  final router = AppRouter(
    environment: environment,
    authController: authController,
  ).router;

  return TrafoDesktopApp(
    environment: environment,
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    authController: authController,
    homeController: homeController,
    router: router,
  );
}
