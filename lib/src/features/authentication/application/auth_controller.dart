import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/models/forgot_password_request.dart';
import '../domain/models/sign_in_request.dart';
import '../domain/models/sign_up_request.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/config_repository.dart';
import 'auth_error_mapper.dart';
import 'auth_state.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required ConfigRepository configRepository,
    required TokenStorage tokenStorage,
  }) : _authRepository = authRepository,
       _configRepository = configRepository,
       _tokenStorage = tokenStorage;

  final AuthRepository _authRepository;
  final ConfigRepository _configRepository;
  final TokenStorage _tokenStorage;

  AuthState _state = const AuthState.initial();
  bool _isHandlingUnauthorized = false;

  AuthState get state => _state;

  Future<void> initialize() async {
    _setState(
      _state.copyWith(operation: AuthOperation.initializing, errorMessage: ''),
    );

    final storedToken = await _tokenStorage.read();

    try {
      final config = await _configRepository.fetchConfig();
      _setState(
        _state.copyWith(
          isReady: true,
          isAuthenticated: storedToken != null && storedToken.isNotEmpty,
          operation: AuthOperation.none,
          tenantName: config.tenantName.isNotEmpty
              ? config.tenantName
              : _state.tenantName,
        ),
      );
    } on ApiException {
      _setState(
        _state.copyWith(
          isReady: true,
          isAuthenticated: storedToken != null && storedToken.isNotEmpty,
          operation: AuthOperation.none,
        ),
      );
    }
  }

  void resetTransientState({bool keepRedirectMessage = true}) {
    _setState(
      _state.copyWith(
        errorMessage: '',
        redirectMessage: keepRedirectMessage ? _state.redirectMessage : '',
        otpIssued: false,
        sessionInfo: '',
      ),
    );
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }

    _setState(_state.copyWith(errorMessage: ''));
  }

  void clearRedirectMessage() {
    if (_state.redirectMessage.isEmpty) {
      return;
    }

    _setState(_state.copyWith(redirectMessage: ''));
  }

  void showRedirectMessage(String message) {
    _setState(_state.copyWith(redirectMessage: message, errorMessage: ''));
  }

  Future<bool> signIn(SignInRequest request) async {
    _setState(
      _state.copyWith(
        operation: AuthOperation.signingIn,
        errorMessage: '',
        redirectMessage: '',
      ),
    );

    try {
      final session = await _authRepository.signIn(request);
      await _tokenStorage.write(session.idToken);
      if (session.refreshToken.isNotEmpty) {
        await _tokenStorage.writeRefreshToken(session.refreshToken);
      }

      _setState(
        _state.copyWith(
          isAuthenticated: true,
          operation: AuthOperation.none,
          errorMessage: '',
          otpIssued: false,
          sessionInfo: '',
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isAuthenticated: false,
          operation: AuthOperation.none,
          errorMessage: mapSignInErrorMessage(
            response: exception.responseData,
            statusCode: exception.statusCode,
            fallbackMessage: exception.message,
          ),
        ),
      );
      return false;
    }
  }

  Future<bool> signUp(SignUpRequest request) async {
    _setState(
      _state.copyWith(operation: AuthOperation.signingUp, errorMessage: ''),
    );

    try {
      await _authRepository.signUp(request);
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: '',
          otpIssued: false,
          sessionInfo: '',
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: mapSignUpErrorMessage(
            response: exception.responseData,
            fallbackMessage: exception.message,
          ),
        ),
      );
      return false;
    }
  }

  Future<bool> sendEmailOtp(String email) async {
    return _sendOtp(
      operation: AuthOperation.sendingOtp,
      action: () => _authRepository.sendEmailOtp(email),
    );
  }

  Future<bool> sendForgotPasswordOtp(String email) async {
    return _sendOtp(
      operation: AuthOperation.sendingOtp,
      action: () => _authRepository.sendForgotPasswordOtp(email),
    );
  }

  Future<bool> resetPasswordByEmail(ForgotPasswordRequest request) async {
    _setState(
      _state.copyWith(
        operation: AuthOperation.resettingPassword,
        errorMessage: '',
      ),
    );

    try {
      await _authRepository.resetPasswordByEmail(request);
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: '',
          otpIssued: false,
          sessionInfo: '',
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: mapGenericAuthErrorMessage(
            response: exception.responseData,
            fallbackMessage: exception.message,
          ),
        ),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    _setState(_state.copyWith(operation: AuthOperation.signingOut));

    try {
      await _authRepository.logout();
    } on ApiException {
      // Logout API failure must not block local sign-out.
    }

    await _tokenStorage.clear();
    _setState(
      _state.copyWith(
        isAuthenticated: false,
        operation: AuthOperation.none,
        errorMessage: '',
        otpIssued: false,
        sessionInfo: '',
      ),
    );
  }

  Future<void> handleUnauthorized() async {
    if (_isHandlingUnauthorized) {
      return;
    }

    _isHandlingUnauthorized = true;
    await _tokenStorage.clear();
    _setState(
      _state.copyWith(
        isAuthenticated: false,
        operation: AuthOperation.none,
        errorMessage: '',
        otpIssued: false,
        sessionInfo: '',
        redirectMessage: 'Session expired. Please log in again.',
      ),
    );
    _isHandlingUnauthorized = false;
  }

  Future<bool> _sendOtp({
    required AuthOperation operation,
    required Future<dynamic> Function() action,
  }) async {
    _setState(
      _state.copyWith(
        operation: operation,
        errorMessage: '',
        otpIssued: false,
        sessionInfo: '',
      ),
    );

    try {
      final result = await action();
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: '',
          otpIssued: result.issued as bool,
          sessionInfo: result.sessionInfo as String,
        ),
      );
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          operation: AuthOperation.none,
          errorMessage: mapGenericAuthErrorMessage(
            response: exception.responseData,
            fallbackMessage: exception.message,
          ),
        ),
      );
      return false;
    }
  }

  void _setState(AuthState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
