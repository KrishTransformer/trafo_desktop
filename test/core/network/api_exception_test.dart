import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/network/api_exception.dart';

void main() {
  final requestOptions = RequestOptions(path: '/auth/signin');

  test('maps timeout errors to timeout ApiException', () {
    final exception = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionTimeout,
    );

    final apiException = ApiException.fromDioException(exception);

    expect(apiException.type, ApiExceptionType.timeout);
    expect(apiException.message, contains('timed out'));
  });

  test('maps connection errors to network ApiException', () {
    final exception = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.connectionError,
    );

    final apiException = ApiException.fromDioException(exception);

    expect(apiException.type, ApiExceptionType.network);
    expect(apiException.message, contains('network connection'));
  });

  test('maps 401 responses to unauthorized ApiException', () {
    final exception = DioException(
      requestOptions: requestOptions,
      response: Response<void>(requestOptions: requestOptions, statusCode: 401),
      type: DioExceptionType.badResponse,
    );

    final apiException = ApiException.fromDioException(exception);

    expect(apiException.type, ApiExceptionType.unauthorized);
    expect(apiException.statusCode, 401);
  });

  test('maps 500 responses to server ApiException', () {
    final exception = DioException(
      requestOptions: requestOptions,
      response: Response<void>(requestOptions: requestOptions, statusCode: 500),
      type: DioExceptionType.badResponse,
    );

    final apiException = ApiException.fromDioException(exception);

    expect(apiException.type, ApiExceptionType.server);
    expect(apiException.message, contains('server'));
  });
}
