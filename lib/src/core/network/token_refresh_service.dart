import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Refreshes the bearer token once for all requests that fail concurrently.
class TokenRefreshService {
  TokenRefreshService({
    required Dio commonClient,
    required TokenStorage tokenStorage,
  }) : _commonClient = commonClient,
       _tokenStorage = tokenStorage;

  final Dio _commonClient;
  final TokenStorage _tokenStorage;
  Future<String>? _refreshRequest;

  Future<String> refresh() {
    return _refreshRequest ??= _refresh().whenComplete(() {
      _refreshRequest = null;
    });
  }

  Future<String> _refresh() async {
    final idToken = await _tokenStorage.read();
    final refreshToken = await _tokenStorage.readRefreshToken();
    final identity = _identityFrom(idToken);
    if (identity.isEmpty || refreshToken == null || refreshToken.isEmpty) {
      throw StateError('No refresh session is available.');
    }

    final basicToken = base64Encode(utf8.encode('$identity:$refreshToken'));
    final response = await _commonClient.post<dynamic>(
      '/auth/signInWithRefreshToken',
      options: Options(headers: <String, Object?>{
        'Authorization': 'Basic $basicToken',
      }),
    );
    final data = Map<String, dynamic>.from(response.data as Map<Object?, Object?>);
    final nextIdToken = _string(data['idToken']) ?? _string(data['id_token']);
    if (nextIdToken == null || nextIdToken.isEmpty) {
      throw const FormatException('The refresh response did not include an ID token.');
    }

    final nextRefreshToken =
        _string(data['refreshToken']) ?? _string(data['refresh_token']) ?? refreshToken;
    await _tokenStorage.write(nextIdToken);
    await _tokenStorage.writeRefreshToken(nextRefreshToken);
    return nextIdToken;
  }

  static String _identityFrom(String? token) {
    if (token == null || token.isEmpty) return '';
    final parts = token.split('.');
    if (parts.length < 2) return '';
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = Map<String, dynamic>.from(jsonDecode(payload) as Map<Object?, Object?>);
      return _string(json['email']) ??
          _string(json['preferred_username']) ??
          _string(json['username']) ??
          '';
    } on FormatException {
      return '';
    }
  }

  static String? _string(Object? value) => value is String ? value : null;
}
