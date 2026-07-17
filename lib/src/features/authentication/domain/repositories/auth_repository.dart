import '../models/auth_session.dart';
import '../models/forgot_password_request.dart';
import '../models/otp_dispatch_result.dart';
import '../models/sign_in_request.dart';
import '../models/sign_up_request.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signIn(SignInRequest request);

  Future<void> signUp(SignUpRequest request);

  Future<OtpDispatchResult> sendEmailOtp(String email);

  Future<OtpDispatchResult> sendForgotPasswordOtp(String email);

  Future<void> resetPasswordByEmail(ForgotPasswordRequest request);

  Future<void> logout();
}
