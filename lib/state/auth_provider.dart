import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import '../api/http_client.dart';
import '../utils/secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _userId;
  String? _userName;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userName => _userName;

  /// Handles login using the AuthService
  Future<bool> login(String username, String password) async {
    final success = await AuthService.login(username, password);
    if (success) {
      _accessToken = await AppStorage.getAccessToken();
      _userId = await AppStorage.getUserId();
      _userName = await AppStorage.getUserName();
      if (_accessToken != null) {
        ApiClient.setToken(_accessToken!); // apply Authorization header
      }
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Refreshes token if needed (not usually called manually)
  Future<bool> refresh() async {
    final success = await AuthService.refresh();
    if (success) {
      _accessToken = await AppStorage.getAccessToken();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Logout and clear tokens
  Future<bool> logout() async {
    final success = await AuthService.logout();
    if (success) {
      _accessToken = null;
      _userId = null;
      _userName = null;
      notifyListeners();
      return true;
    }
    return false;
  }
}
