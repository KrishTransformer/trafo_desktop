import 'package:flutter/foundation.dart';

enum AuthOperation {
  none,
  initializing,
  signingIn,
  signingUp,
  sendingOtp,
  resettingPassword,
  signingOut,
}

@immutable
class AuthState {
  const AuthState({
    required this.isReady,
    required this.isAuthenticated,
    required this.operation,
    required this.tenantName,
    required this.errorMessage,
    required this.redirectMessage,
    required this.otpIssued,
    required this.sessionInfo,
  });

  const AuthState.initial()
    : isReady = false,
      isAuthenticated = false,
      operation = AuthOperation.none,
      tenantName = 'K R I S H',
      errorMessage = '',
      redirectMessage = '',
      otpIssued = false,
      sessionInfo = '';

  final bool isReady;
  final bool isAuthenticated;
  final AuthOperation operation;
  final String tenantName;
  final String errorMessage;
  final String redirectMessage;
  final bool otpIssued;
  final String sessionInfo;

  bool get isBusy => operation != AuthOperation.none;

  AuthState copyWith({
    bool? isReady,
    bool? isAuthenticated,
    AuthOperation? operation,
    String? tenantName,
    String? errorMessage,
    String? redirectMessage,
    bool? otpIssued,
    String? sessionInfo,
  }) {
    return AuthState(
      isReady: isReady ?? this.isReady,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      operation: operation ?? this.operation,
      tenantName: tenantName ?? this.tenantName,
      errorMessage: errorMessage ?? this.errorMessage,
      redirectMessage: redirectMessage ?? this.redirectMessage,
      otpIssued: otpIssued ?? this.otpIssued,
      sessionInfo: sessionInfo ?? this.sessionInfo,
    );
  }
}
