import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../domain/models/sign_up_request.dart';
import 'widgets/auth_view_scaffold.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        final state = _authController.state;

        return AuthViewScaffold(
          title: 'Sign Up',
          tenantName: state.tenantName,
          footer: const AuthFooterLink(
            prefix: 'Exsisting User ? ',
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
                  message:
                      'OTP was requested successfully. You can continue signup.',
                  backgroundColor: Color(0xFFEAF7ED),
                  foregroundColor: Color(0xFF1D6A37),
                ),
              const AuthFieldLabel('Username'),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: 'Create a username',
                ),
              ),
              const SizedBox(height: 16),
              const AuthFieldLabel('Password'),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  hintText: 'Create a password',
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
              const SizedBox(height: 16),
              const AuthFieldLabel('Confirm Password'),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const AuthFieldLabel('Email ID'),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 300;
                  final emailField = TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email address',
                    ),
                  );
                  final otpButton = OutlinedButton(
                    onPressed: state.operation == AuthOperation.sendingOtp
                        ? null
                        : _sendOtp,
                    child: state.operation == AuthOperation.sendingOtp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Get OTP'),
                  );
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            emailField,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: otpButton,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: emailField),
                            const SizedBox(width: 12),
                            otpButton,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              const AuthFieldLabel('OTP'),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(hintText: 'Enter the OTP'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.operation == AuthOperation.signingUp
                    ? null
                    : _submit,
                child: state.operation == AuthOperation.signingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign Up'),
              ),
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

    final emailId = _emailController.text;
    if (emailId.trim().isEmpty) {
      setState(() {
        _localError = 'Email ID is required';
      });
      return;
    }
    if (RegExp(r'\s').hasMatch(emailId)) {
      setState(() {
        _localError = 'Spaces are not allowed in Email ID';
      });
      return;
    }
    if (!emailId.contains('@')) {
      setState(() {
        _localError = 'Email ID is not valid';
      });
      return;
    }

    await _authController.sendEmailOtp(emailId.trim());
  }

  Future<void> _submit() async {
    _authController.clearErrorMessage();
    setState(() {
      _localError = '';
    });

    final username = _usernameController.text;
    final emailId = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final otp = _otpController.text;

    if (emailId.trim().isEmpty) {
      setState(() {
        _localError = 'Email ID is required';
      });
      return;
    }
    if (!emailId.contains('@')) {
      setState(() {
        _localError = 'Email ID is not valid';
      });
      return;
    }
    if (username.trim().isEmpty) {
      setState(() {
        _localError = 'Username is required';
      });
      return;
    }
    if (RegExp(r'\s').hasMatch(username) ||
        RegExp(r'\s').hasMatch(emailId) ||
        RegExp(r'\s').hasMatch(password) ||
        RegExp(r'\s').hasMatch(confirmPassword) ||
        RegExp(r'\s').hasMatch(otp)) {
      setState(() {
        _localError = 'Spaces are not allowed in Sign Up fields';
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _localError = 'Password should have at least 6 characters';
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _localError = 'Passwords not matched';
      });
      return;
    }
    if (otp.trim().isEmpty) {
      setState(() {
        _localError = 'OTP is required';
      });
      return;
    }

    final success = await _authController.signUp(
      SignUpRequest(
        username: username.trim(),
        password: password,
        email: emailId.trim(),
        otp: otp.trim(),
      ),
    );

    if (success && mounted) {
      _authController.showRedirectMessage('Sign Up succeeded. Please sign in.');
      context.go(RoutePaths.login);
    }
  }
}
