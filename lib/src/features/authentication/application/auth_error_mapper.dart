String mapSignInErrorMessage({
  required Object? response,
  required int? statusCode,
  required String fallbackMessage,
}) {
  final rawError = _extractAuthErrorText(response) ?? fallbackMessage;
  final normalized = rawError.toUpperCase();

  if (normalized.contains('EMAIL_NOT_FOUND') ||
      normalized.contains('USER_NOT_FOUND')) {
    return 'Please register';
  }

  if (statusCode == 401 ||
      normalized.contains('INVALID_PASSWORD') ||
      normalized.contains('INVALID_CREDENTIAL') ||
      normalized.contains('BAD_CREDENTIAL') ||
      normalized.contains('UNAUTHORIZED')) {
    return 'Invalid Username or Password';
  }

  return _processErrorMessage(rawError);
}

String mapSignUpErrorMessage({
  required Object? response,
  required String fallbackMessage,
}) {
  final rawError = _extractAuthErrorText(response) ?? fallbackMessage;
  final normalized = rawError.toUpperCase();

  if (normalized.contains('EMAIL_EXISTS') ||
      normalized.contains('EMAIL_ALREADY_EXISTS') ||
      normalized.contains('USER_ALREADY_EXISTS')) {
    return 'Email is already registered. Please sign in.';
  }

  if (normalized.contains('USERNAME_EXISTS') ||
      normalized.contains('USERNAME_ALREADY_EXISTS')) {
    return 'Username is already taken.';
  }

  if (normalized.contains('INVALID_OTP')) {
    return 'Invalid OTP. Please try again.';
  }

  if (normalized.contains('OTP_EXPIRED')) {
    return 'OTP expired. Please request a new OTP.';
  }

  if (normalized.contains('INVALID_EMAIL')) {
    return 'Please enter a valid email address.';
  }

  return _processErrorMessage(rawError);
}

String mapGenericAuthErrorMessage({
  required Object? response,
  required String fallbackMessage,
}) {
  final rawError = _extractAuthErrorText(response) ?? fallbackMessage;
  return _processErrorMessage(rawError);
}

String? _extractAuthErrorText(Object? response) {
  if (response == null) {
    return null;
  }

  if (response is String) {
    return response;
  }

  if (response is Map<String, dynamic>) {
    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      final firstError = errors.first;
      if (firstError is String) {
        return firstError;
      }
      if (firstError is Map<String, dynamic>) {
        return firstError['message']?.toString() ??
            firstError['error']?.toString() ??
            firstError['code']?.toString();
      }
    }

    final error = response['error'];
    if (error is Map<String, dynamic>) {
      return error['message']?.toString() ?? error['error']?.toString();
    }

    return error?.toString() ??
        response['message']?.toString() ??
        response['code']?.toString() ??
        (response['data'] is Map<String, dynamic>
            ? (response['data'] as Map<String, dynamic>)['error']?.toString() ??
                  (response['data'] as Map<String, dynamic>)['message']
                      ?.toString()
            : null);
  }

  return response.toString();
}

String _processErrorMessage(String inputErrorMessage) {
  return switch (inputErrorMessage) {
    'EMAIL_NOT_FOUND' => 'Email is not registered, Please contact admin',
    'INVALID_EMAIL' => 'Email is Invalid',
    'INVALID_PASSWORD' => 'Password is Invalid',
    _ => inputErrorMessage,
  };
}
