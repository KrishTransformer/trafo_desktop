import 'dart:io';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

class BearerTokenInterceptor extends Interceptor {
  BearerTokenInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuthHeader = options.headers['X-Skip-Auth'];
    if (skipAuthHeader == 'true') {
      options.headers.remove('X-Skip-Auth');
      handler.next(options);
      return;
    }

    final token = await _tokenStorage.read();

    final hasAuthorization = options.headers.keys.any(
      (key) => key.toLowerCase() == HttpHeaders.authorizationHeader,
    );
    if (token != null && token.isNotEmpty && !hasAuthorization) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    handler.next(options);
  }
}
