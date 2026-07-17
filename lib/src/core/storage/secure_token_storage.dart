import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const String _tokenKey = 'auth_bearer_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);
}
