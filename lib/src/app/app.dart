import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_environment.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/home/application/home_controller.dart';
import 'app_scope.dart';
import 'app_theme.dart';

class TrafoDesktopApp extends StatelessWidget {
  const TrafoDesktopApp({
    required this.environment,
    required this.apiClient,
    required this.tokenStorage,
    required this.authController,
    required this.homeController,
    required this.router,
    super.key,
  });

  final AppEnvironment environment;
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final AuthController authController;
  final HomeController homeController;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: AppDependencies(
        environment: environment,
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        authController: authController,
        homeController: homeController,
      ),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Trafo Desktop',
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    );
  }
}
