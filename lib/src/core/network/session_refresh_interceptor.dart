import 'package:dio/dio.dart';

import 'token_refresh_service.dart';

typedef UnauthorizedHandler = Future<void> Function();

class SessionRefreshInterceptor extends Interceptor {
  SessionRefreshInterceptor({
    required Dio client,
    required TokenRefreshService tokenRefreshService,
    required UnauthorizedHandler onRefreshFailure,
  }) : _client = client,
       _tokenRefreshService = tokenRefreshService,
       _onRefreshFailure = onRefreshFailure;

  final Dio _client;
  final TokenRefreshService _tokenRefreshService;
  final UnauthorizedHandler _onRefreshFailure;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isRefreshable(err) || options.extra['retriedAfterRefresh'] == true) {
      handler.next(err);
      return;
    }

    try {
      final token = await _tokenRefreshService.refresh();
      options.extra['retriedAfterRefresh'] = true;
      options.headers['Authorization'] = 'Bearer $token';
      options.headers.remove('authorization');
      final response = await _client.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (_) {
      await _onRefreshFailure();
      handler.next(err);
    }
  }

  static bool _isRefreshable(DioException error) {
    final statusCode = error.response?.statusCode;
    final headers = error.requestOptions.headers;
    final authorization = headers['Authorization'] ?? headers['authorization'];
    return (statusCode == 401 || statusCode == 403) &&
        authorization is String &&
        authorization.startsWith('Bearer ');
  }
}
