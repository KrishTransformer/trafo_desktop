abstract interface class TokenStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> clear();
}
