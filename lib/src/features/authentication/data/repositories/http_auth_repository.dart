import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/forgot_password_request.dart';
import '../../domain/models/otp_dispatch_result.dart';
import '../../domain/models/sign_in_request.dart';
import '../../domain/models/sign_up_request.dart';
import '../../domain/repositories/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> logout() {
    return _apiClient.post<void>(
      service: ApiService.common,
      path: '/auth/logout',
      data: const <String, dynamic>{},
      decoder: (_) {},
    );
  }

  @override
  Future<void> resetPasswordByEmail(ForgotPasswordRequest request) {
    return _apiClient.post<void>(
      service: ApiService.common,
      path: '/auth/passwordResetByEmail',
      data: request.toJson(),
      headers: const <String, Object?>{'X-Skip-Auth': 'true'},
      decoder: (_) {},
    );
  }

  @override
  Future<OtpDispatchResult> sendEmailOtp(String email) {
    return _sendOtp('/auth/sendEmailOtp', email);
  }

  @override
  Future<OtpDispatchResult> sendForgotPasswordOtp(String email) {
    return _sendOtp('/auth/sendForgotPasswordOtp', email);
  }

  @override
  Future<AuthSession> signIn(SignInRequest request) {
    final basicToken = base64Encode(
      utf8.encode('${request.usernameOrEmail}:${request.password}'),
    );

    return _apiClient.post<AuthSession>(
      service: ApiService.common,
      path: '/auth/signin',
      data: request.toJson(),
      headers: <String, Object?>{'Authorization': 'Basic $basicToken'},
      decoder: (data) => AuthSession.fromJson(
        Map<String, dynamic>.from(data as Map<Object?, Object?>),
      ),
    );
  }

  @override
  Future<void> signUp(SignUpRequest request) {
    return _apiClient.post<void>(
      service: ApiService.common,
      path: '/auth/signup',
      data: request.toJson(),
      headers: const <String, Object?>{'X-Skip-Auth': 'true'},
      decoder: (_) {},
    );
  }

  Future<OtpDispatchResult> _sendOtp(String path, String email) {
    return _apiClient.post<OtpDispatchResult>(
      service: ApiService.common,
      path: path,
      data: <String, dynamic>{'email': email},
      headers: const <String, Object?>{'X-Skip-Auth': 'true'},
      decoder: (data) {
        final json = Map<String, dynamic>.from(data as Map<Object?, Object?>);
        return OtpDispatchResult.fromJson(json);
      },
    );
  }
}
