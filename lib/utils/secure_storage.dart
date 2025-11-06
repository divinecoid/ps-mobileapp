import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const _storage = FlutterSecureStorage();

  static Future<void> setAccessToken(String token) =>
      _storage.write(key: "access_token", value: token);

  static Future<void> setRefreshToken(String token) =>
      _storage.write(key: "refresh_token", value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: "access_token");

  static Future<String?> getRefreshToken() =>
      _storage.read(key: "refresh_token");

  static Future<void> clear() => _storage.deleteAll();
}
