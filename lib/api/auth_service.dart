import 'package:dio/dio.dart';
import '../utils/secure_storage.dart';
import 'http_client.dart';
import 'endpoints.dart';

class AuthService {
  /// LOGIN → Calls Laravel /login endpoint
  static Future<bool> login(String username, String password) async {
    try {
      print('🔐 Attempting login for username: $username');
      print('📡 API URL: ${ApiClient.dio.options.baseUrl}${Endpoint.login}');

      final response = await ApiClient.dio.post(
        Endpoint.login,
        data: {'username': username, 'password': password},
      );

      print('✅ Login response status: ${response.statusCode}');
      print('📦 Login response data: ${response.data}');

      // Extract tokens from backend response
      final accessToken = response.data['token'];
      final refreshToken = response.data['refresh_token'];

      if (accessToken == null || refreshToken == null) {
        print('❌ Missing tokens in response!');
        print('   - accessToken: $accessToken');
        print('   - refreshToken: $refreshToken');
        return false;
      }

      // Store tokens securely
      await AppStorage.setAccessToken(accessToken);
      await AppStorage.setRefreshToken(refreshToken);

      // Apply token to headers for future API calls
      ApiClient.setToken(accessToken);

      print('✅ Login successful! Tokens stored.');
      return true;
    } on DioException catch (e) {
      print('❌ Login failed with DioException:');
      print('   - Type: ${e.type}');
      print('   - Message: ${e.message}');
      print('   - Status Code: ${e.response?.statusCode}');
      print('   - Response Data: ${e.response?.data}');
      print('   - Error: ${e.error}');
      return false;
    } catch (e) {
      print('❌ Login failed with unexpected error: $e');
      return false;
    }
  }

  /// REFRESH TOKEN → Calls Laravel /refresh
  static Future<bool> refresh() async {
    try {
      final refreshToken = await AppStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await ApiClient.dio.post(
        Endpoint.refresh,
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['token'];

      // Store and apply new token
      await AppStorage.setAccessToken(newAccessToken);
      ApiClient.setToken(newAccessToken);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// LOGOUT → Calls Laravel /logout and clears tokens
  static Future<bool> logout() async {
    final refreshToken = await AppStorage.getRefreshToken();
    try {
      if (refreshToken != null) {
        final response = await ApiClient.dio.post(
          Endpoint.logout,
          data: {'refresh_token': refreshToken},
        );

        // Check if API returned success: false (e.g., invalid refresh token)
        if (response.data['success'] == false) {
          print('⚠️ Logout failed: ${response.data['message']}');
          // Still clear local tokens even if server rejects
          await AppStorage.clear();
          return false;
        }
      }

      // Remove tokens locally
      await AppStorage.clear();
      return true;
    } catch (e) {
      print('❌ Logout error: $e');
      // Clear tokens anyway to force logout locally
      await AppStorage.clear();
      return false;
    }
  }
}
