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
      options.headers.remove(HttpHeaders.authorizationHeader);
      options.headers.remove('authorization');
      handler.next(options);
      return;
    }

    final token = await _tokenStorage.read();

    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey(HttpHeaders.authorizationHeader)) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    handler.next(options);
  }
}
