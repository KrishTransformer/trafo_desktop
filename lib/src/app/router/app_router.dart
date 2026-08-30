import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/authentication/presentation/sign_up_screen.dart';
import '../../features/core_model/presentation/core_model_screen.dart';
import '../../features/design_workspace/presentation/two_winding_screen.dart';
import '../../features/multi_winding/presentation/multi_winding_screen.dart';
import '../../features/fabrication/presentation/fabrication_screen.dart';
import '../../features/files/presentation/files_screen.dart';
import '../../features/home/domain/models/design_summary.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lom_cost/presentation/lom_cost_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../shell/desktop_navigation_shell.dart';
import 'route_paths.dart';

class AppRouter {
  AppRouter({
    required AppEnvironment environment,
    required AuthController authController,
  }) : router = GoRouter(
         initialLocation: RoutePaths.login,
         refreshListenable: authController,
         redirect: (context, state) {
           final isAuthenticated = authController.state.isAuthenticated;
           final currentPath = state.matchedLocation;
           final isPublicRoute =
               currentPath == RoutePaths.login ||
               currentPath == RoutePaths.signUp ||
               currentPath == RoutePaths.forgotPassword;

           if (!isAuthenticated && !isPublicRoute) {
             return RoutePaths.login;
           }

           if (isAuthenticated && isPublicRoute) {
             return RoutePaths.home;
           }

           return null;
         },
         routes: [
           GoRoute(
             path: RoutePaths.login,
             builder: (context, state) => const LoginScreen(),
           ),
           GoRoute(
             path: RoutePaths.signUp,
             builder: (context, state) => const SignUpScreen(),
           ),
           GoRoute(
             path: RoutePaths.forgotPassword,
             builder: (context, state) => const ForgotPasswordScreen(),
           ),
           StatefulShellRoute.indexedStack(
             builder: (context, state, navigationShell) {
               return DesktopNavigationShell(
                 environment: environment,
                 navigationShell: navigationShell,
               );
             },
             branches: [
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.home,
                     builder: (context, state) => const HomeScreen(),
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.multiWindings,
                     builder: (context, state) => MultiWindingScreen(
                       routeDesignId: 'new',
                       initialDesignSummary: state.extra is DesignSummary
                           ? state.extra as DesignSummary
                           : null,
                     ),
                     routes: [
                       GoRoute(
                         path: ':designId',
                         builder: (context, state) => MultiWindingScreen(
                           routeDesignId:
                               state.pathParameters['designId'] ?? 'new',
                           initialDesignSummary: state.extra is DesignSummary
                               ? state.extra as DesignSummary
                               : null,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.twoWindings,
                     builder: (context, state) => TwoWindingScreen(
                       routeDesignId: 'new',
                       initialDesignSummary: state.extra is DesignSummary
                           ? state.extra as DesignSummary
                           : null,
                     ),
                     routes: [
                       GoRoute(
                         path: ':designId',
                         builder: (context, state) => TwoWindingScreen(
                           routeDesignId:
                               state.pathParameters['designId'] ?? 'new',
                           initialDesignSummary: state.extra is DesignSummary
                               ? state.extra as DesignSummary
                               : null,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.core,
                     builder: (context, state) =>
                         const CoreModelScreen(routeDesignId: ''),
                     routes: [
                       GoRoute(
                         path: ':designId',
                         builder: (context, state) => CoreModelScreen(
                           routeDesignId:
                               state.pathParameters['designId'] ?? '',
                           initialDesignSummary: state.extra is DesignSummary
                               ? state.extra as DesignSummary
                               : null,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.fabrication,
                     builder: (context, state) =>
                         const FabricationScreen(routeDesignId: ''),
                     routes: [
                       GoRoute(
                         path: ':designId',
                         builder: (context, state) => FabricationScreen(
                           routeDesignId:
                               state.pathParameters['designId'] ?? '',
                           initialDesignSummary: state.extra is DesignSummary
                               ? state.extra as DesignSummary
                               : null,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.files,
                     builder: (context, state) =>
                         const FilesScreen(routeDesignId: ''),
                     routes: [
                       GoRoute(
                         path: ':designId',
                         builder: (context, state) => FilesScreen(
                           routeDesignId:
                               state.pathParameters['designId'] ?? '',
                           initialDesignSummary: state.extra is DesignSummary
                               ? state.extra as DesignSummary
                               : null,
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.profile,
                     builder: (context, state) => const ProfileScreen(),
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.users,
                     builder: (context, state) => const UsersScreen(),
                   ),
                 ],
               ),
               StatefulShellBranch(
                 routes: [
                   GoRoute(
                     path: RoutePaths.lomCost,
                     builder: (context, state) => const LomCostScreen(),
                   ),
                 ],
               ),
             ],
           ),
         ],
       );

  final GoRouter router;
}
