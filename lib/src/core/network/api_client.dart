import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'api_service.dart';
import 'bearer_token_interceptor.dart';
import 'session_refresh_interceptor.dart';
import 'token_refresh_service.dart';

typedef JsonDecoder<T> = T Function(dynamic data);
typedef UnauthorizedCallback = Future<void> Function();

class ApiClient {
  ApiClient({
    required AppEnvironment environment,
    required TokenStorage tokenStorage,
    UnauthorizedCallback? onUnauthorized,
  }) {
    final clients = <ApiService, Dio>{
      for (final service in ApiService.values)
        service: Dio(
          BaseOptions(
            baseUrl: environment.baseUrls.forService(service).toString(),
            connectTimeout: environment.connectTimeout,
            receiveTimeout: environment.receiveTimeout,
            sendTimeout: environment.connectTimeout,
            responseType: ResponseType.json,
            headers: const {'Accept': 'application/json'},
          ),
        ),
    };
    final refreshService = TokenRefreshService(
      commonClient: clients[ApiService.common]!,
      tokenStorage: tokenStorage,
    );
    for (final client in clients.values) {
      client.interceptors.add(BearerTokenInterceptor(tokenStorage));
      client.interceptors.add(
        SessionRefreshInterceptor(
          client: client,
          tokenRefreshService: refreshService,
          onRefreshFailure: onUnauthorized ?? (() async {}),
        ),
      );
    }
    _clients = clients;
  }

  late final Map<ApiService, Dio> _clients;

  Dio clientFor(ApiService service) => _clients[service]!;

  Future<T> get<T>({
    required ApiService service,
    required String path,
    required JsonDecoder<T> decoder,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? headers,
    ResponseType? responseType,
  }) {
    return _request(
      service: service,
      path: path,
      method: 'GET',
      decoder: decoder,
      queryParameters: queryParameters,
      headers: headers,
      responseType: responseType,
    );
  }

  Future<T> post<T>({
    required ApiService service,
    required String path,
    required JsonDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? headers,
    ResponseType? responseType,
  }) {
    return _request(
      service: service,
      path: path,
      method: 'POST',
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      responseType: responseType,
    );
  }

  Future<T> put<T>({
    required ApiService service,
    required String path,
    required JsonDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? headers,
    ResponseType? responseType,
  }) {
    return _request(
      service: service,
      path: path,
      method: 'PUT',
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      responseType: responseType,
    );
  }

  Future<T> delete<T>({
    required ApiService service,
    required String path,
    required JsonDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? headers,
    ResponseType? responseType,
  }) {
    return _request(
      service: service,
      path: path,
      method: 'DELETE',
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      responseType: responseType,
    );
  }

  Future<T> _request<T>({
    required ApiService service,
    required String path,
    required String method,
    required JsonDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? headers,
    ResponseType? responseType,
  }) async {
    try {
      final response = await clientFor(service).request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          responseType: responseType,
        ),
      );

      return decoder(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
