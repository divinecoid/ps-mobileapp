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

  static Future<void> setUserId(String id) => _storage.write(key: "user_id", value: id);

  static Future<void> setUserName(String name) =>
      _storage.write(key: "user_name", value: name);

  static Future<String?> getUserId() => _storage.read(key: "user_id");

  static Future<String?> getUserName() => _storage.read(key: "user_name");

  static Future<void> clear() => _storage.deleteAll();
}
