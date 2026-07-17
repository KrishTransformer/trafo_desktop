import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../domain/models/forgot_password_request.dart';
import 'widgets/auth_view_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _localError = '';

  AuthController get _authController => AppScope.of(context).authController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.resetTransientState(keepRedirectMessage: false);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
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
          title: 'Forgot Password?',
          tenantName: state.tenantName,
          footer: const AuthFooterLink(
            prefix: 'Back to SignIn? ',
            linkLabel: 'Sign In',
            route: RoutePaths.login,
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
              if (state.otpIssued)
                const AuthMessageBanner(
                  message: 'OTP sent to the registered email',
                  backgroundColor: Color(0xFFEAF7ED),
                  foregroundColor: Color(0xFF1D6A37),
                ),
              const AuthFieldLabel('Email'),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Enter your registered email',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.operation == AuthOperation.sendingOtp
                    ? null
                    : _sendOtp,
                child: state.operation == AuthOperation.sendingOtp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send OTP'),
              ),
              if (state.otpIssued) ...[
                const SizedBox(height: 20),
                const AuthFieldLabel('OTP'),
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(hintText: 'Enter the OTP'),
                ),
                const SizedBox(height: 16),
                const AuthFieldLabel('New Password'),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Create a new password',
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
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: state.operation == AuthOperation.resettingPassword
                      ? null
                      : _resetPassword,
                  child: state.operation == AuthOperation.resettingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendOtp() async {
    _authController.clearErrorMessage();
    setState(() {
      _localError = '';
    });

    final email = _emailController.text;
    if (email.trim().isEmpty) {
      setState(() {
        _localError = 'Email is required';
      });
      return;
    }

    await _authController.sendForgotPasswordOtp(email.trim());
  }

  Future<void> _resetPassword() async {
    _authController.clearErrorMessage();
    setState(() {
      _localError = '';
    });

    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _localError = 'OTP is required';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _localError = 'Password should have at least 6 characters';
      });
      return;
    }

    final success = await _authController.resetPasswordByEmail(
      ForgotPasswordRequest(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      ),
    );

    if (success && mounted) {
      _authController.showRedirectMessage(
        'Password reset succeeded. Please sign in.',
      );
      context.go(RoutePaths.login);
    }
  }
}
