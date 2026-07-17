import 'package:dio/dio.dart';

typedef UnauthorizedHandler = Future<void> Function();

class UnauthorizedSessionInterceptor extends Interceptor {
  UnauthorizedSessionInterceptor(this._onUnauthorized);

  final UnauthorizedHandler _onUnauthorized;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final authorizationHeader =
        err.requestOptions.headers['Authorization'] ??
        err.requestOptions.headers['authorization'];
    final hadBearerToken =
        authorizationHeader is String &&
        authorizationHeader.startsWith('Bearer ');

    if (hadBearerToken && (statusCode == 401 || statusCode == 403)) {
      await _onUnauthorized();
    }

    handler.next(err);
  }
}
