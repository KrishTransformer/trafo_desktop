import 'package:flutter/widgets.dart';

import '../core/config/app_environment.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../features/authentication/application/auth_controller.dart';
import '../features/home/application/home_controller.dart';

class AppDependencies {
  const AppDependencies({
    required this.environment,
    required this.apiClient,
    required this.tokenStorage,
    required this.authController,
    required this.homeController,
  });

  final AppEnvironment environment;
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final AuthController authController;
  final HomeController homeController;
}

class AppScope extends InheritedWidget {
  const AppScope({required this.dependencies, required super.child, super.key});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw FlutterError(
        'AppScope not found in widget tree. Wrap the application with AppScope.',
      );
    }
    return scope.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
