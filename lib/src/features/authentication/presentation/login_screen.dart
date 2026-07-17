import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../domain/models/sign_in_request.dart';
import 'widgets/auth_view_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _localError = '';

  AuthController get _authController => AppScope.of(context).authController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.resetTransientState();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        final state = _authController.state;

        return AuthViewScaffold(
          title: 'Sign In',
          tenantName: state.tenantName,
          footer: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(RoutePaths.forgotPassword),
                  child: const Text('Forgot Password?'),
                ),
              ),
              const AuthFooterLink(
                prefix: 'Not Registered? ',
                linkLabel: 'Sign Up',
                route: RoutePaths.signUp,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.errorMessage.isNotEmpty)
                AuthMessageBanner(
                  message: state.errorMessage,
                  backgroundColor: const Color(0xFFFDECEC),
                  foregroundColor: const Color(0xFF8D1F1F),
                ),
              if (_localError.isNotEmpty)
                AuthMessageBanner(
                  message: _localError,
                  backgroundColor: const Color(0xFFFDECEC),
                  foregroundColor: const Color(0xFF8D1F1F),
                ),
              if (state.redirectMessage.isNotEmpty)
                AuthMessageBanner(
                  message: state.redirectMessage,
                  backgroundColor: const Color(0xFFEAF7ED),
                  foregroundColor: const Color(0xFF1D6A37),
                ),
              const AuthFieldLabel('Username / Email'),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Enter your username or email',
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              const AuthFieldLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.operation == AuthOperation.signingIn
                    ? null
                    : _submit,
                child: state.operation == AuthOperation.signingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    _authController.clearErrorMessage();
    setState(() {
      _localError = '';
    });

    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _localError = 'Please fill out all fields.';
      });
      return;
    }

    if (RegExp(r'\s').hasMatch(username) || RegExp(r'\s').hasMatch(password)) {
      setState(() {
        _localError = 'Spaces are not allowed in Username / Email or Password';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _localError = 'Password should have atleast 6 characters';
      });
      return;
    }

    final success = await _authController.signIn(
      SignInRequest(usernameOrEmail: username.trim(), password: password),
    );

    if (success && mounted) {
      context.go(RoutePaths.home);
    }
  }
}
