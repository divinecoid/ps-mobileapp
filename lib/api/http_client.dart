import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {"Accept": "application/json"},
    ),
  );

  static setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }
}
