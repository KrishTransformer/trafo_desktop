import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trafo_desktop/src/core/network/token_refresh_service.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';

void main() {
  test('refreshes and persists the replacement session tokens', () async {
    final storage = _MemoryTokenStorage(
      token: _jwtWithEmail('engineer@example.com'),
      refreshToken: 'old-refresh-token',
    );
    final adapter = _ResponseAdapter();
    final client = Dio()..httpClientAdapter = adapter;
    final service = TokenRefreshService(
      commonClient: client,
      tokenStorage: storage,
    );

    final token = await service.refresh();

    expect(token, 'new-id-token');
    expect(storage.token, 'new-id-token');
    expect(storage.refreshToken, 'new-refresh-token');
    expect(adapter.requests, 1);
    expect(adapter.authorization, startsWith('Basic '));
  });

  test('shares one refresh request for concurrent unauthorized calls', () async {
    final storage = _MemoryTokenStorage(
      token: _jwtWithEmail('engineer@example.com'),
      refreshToken: 'old-refresh-token',
    );
    final adapter = _ResponseAdapter(delay: const Duration(milliseconds: 10));
    final client = Dio()..httpClientAdapter = adapter;
    final service = TokenRefreshService(
      commonClient: client,
      tokenStorage: storage,
    );

    final tokens = await Future.wait(<Future<String>>[
      service.refresh(),
      service.refresh(),
    ]);

    expect(tokens, <String>['new-id-token', 'new-id-token']);
    expect(adapter.requests, 1);
  });
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({required this.token, required this.refreshToken});

  String? token;
  String? refreshToken;

  @override
  Future<void> clear() async {
    token = null;
    refreshToken = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> write(String value) async => token = value;

  @override
  Future<void> writeRefreshToken(String value) async => refreshToken = value;
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter({this.delay});

  final Duration? delay;
  var requests = 0;
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    authorization = options.headers['Authorization'] as String?;
    if (delay != null) await Future<void>.delayed(delay!);
    return ResponseBody.fromString(
      '{"idToken":"new-id-token","refreshToken":"new-refresh-token"}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _jwtWithEmail(String email) {
  final payload = base64Url.encode(utf8.encode('{"email":"$email"}'));
  return 'header.$payload.signature';
}
