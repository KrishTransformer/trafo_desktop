import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/network/bearer_token_interceptor.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';

void main() {
  test('adds bearer token header when a token exists', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://common.example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(BearerTokenInterceptor(_FakeTokenStorage('abc123')));

    await dio.get<Map<String, dynamic>>('/config');

    expect(adapter.lastOptions?.headers['Authorization'], 'Bearer abc123');
  });

  test('does not add authorization header when no token exists', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://common.example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(BearerTokenInterceptor(_FakeTokenStorage(null)));

    await dio.get<Map<String, dynamic>>('/config');

    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage(this._token);

  final String? _token;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => _token;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> writeRefreshToken(String token) async {}
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
