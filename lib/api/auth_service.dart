import 'http_client.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await ApiClient.dio.post('/login', data: {
      'username': username,
      'password': password,
    });

    return response.data;
  }
}
