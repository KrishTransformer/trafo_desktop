import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum ApiExceptionType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  badResponse,
  unknown,
}

@immutable
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.uri,
    this.responseData,
    this.cause,
  });

  factory ApiException.fromDioException(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          type: ApiExceptionType.timeout,
          message: 'The request timed out. Please try again.',
          statusCode: statusCode,
          uri: exception.requestOptions.uri,
          responseData: response?.data,
          cause: exception,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          type: ApiExceptionType.network,
          message: 'A network connection could not be established.',
          statusCode: statusCode,
          uri: exception.requestOptions.uri,
          responseData: response?.data,
          cause: exception,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          type: _typeFromStatusCode(statusCode),
          message: _messageFromStatusCode(statusCode),
          statusCode: statusCode,
          uri: exception.requestOptions.uri,
          responseData: response?.data,
          cause: exception,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiException(
          type: ApiExceptionType.unknown,
          message: 'An unexpected error occurred while contacting the server.',
          statusCode: statusCode,
          uri: exception.requestOptions.uri,
          responseData: response?.data,
          cause: exception,
        );
    }
  }

  final ApiExceptionType type;
  final String message;
  final int? statusCode;
  final Uri? uri;
  final Object? responseData;
  final Object? cause;

  static ApiExceptionType _typeFromStatusCode(int? statusCode) {
    if (statusCode == null) {
      return ApiExceptionType.badResponse;
    }

    return switch (statusCode) {
      401 => ApiExceptionType.unauthorized,
      403 => ApiExceptionType.forbidden,
      404 => ApiExceptionType.notFound,
      >= 500 => ApiExceptionType.server,
      _ => ApiExceptionType.badResponse,
    };
  }

  static String _messageFromStatusCode(int? statusCode) {
    if (statusCode == null) {
      return 'The server returned an unexpected response.';
    }

    return switch (statusCode) {
      401 => 'Your session is no longer valid. Please sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested resource could not be found.',
      >= 500 => 'The server could not complete the request.',
      _ => 'The server returned an unexpected response.',
    };
  }

  @override
  String toString() {
    return 'ApiException(type: $type, statusCode: $statusCode, message: $message, uri: $uri)';
  }
}
