import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/authentication/application/auth_error_mapper.dart';

void main() {
  group('mapSignInErrorMessage', () {
    test('maps missing-account errors to registration guidance', () {
      final message = mapSignInErrorMessage(
        response: const <String, dynamic>{'error': 'EMAIL_NOT_FOUND'},
        statusCode: 404,
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Please register');
    });

    test('maps unauthorized credential failures to invalid credentials copy', () {
      final message = mapSignInErrorMessage(
        response: const <String, dynamic>{'error': 'INVALID_PASSWORD'},
        statusCode: 401,
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Invalid Username or Password');
    });
  });

  group('mapSignUpErrorMessage', () {
    test('maps duplicate email failures', () {
      final message = mapSignUpErrorMessage(
        response: const <String, dynamic>{'error': 'EMAIL_EXISTS'},
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Email is already registered. Please sign in.');
    });

    test('maps duplicate username failures', () {
      final message = mapSignUpErrorMessage(
        response: const <String, dynamic>{'error': 'USERNAME_EXISTS'},
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Username is already taken.');
    });

    test('maps invalid otp failures', () {
      final message = mapSignUpErrorMessage(
        response: const <String, dynamic>{'error': 'INVALID_OTP'},
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Invalid OTP. Please try again.');
    });

    test('maps expired otp failures', () {
      final message = mapSignUpErrorMessage(
        response: const <String, dynamic>{'error': 'OTP_EXPIRED'},
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'OTP expired. Please request a new OTP.');
    });

    test('maps invalid email failures', () {
      final message = mapSignUpErrorMessage(
        response: const <String, dynamic>{'error': 'INVALID_EMAIL'},
        fallbackMessage: 'Unexpected error',
      );

      expect(message, 'Please enter a valid email address.');
    });
  });
}
