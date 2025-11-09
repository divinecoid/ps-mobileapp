import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/secure_storage.dart';
import 'auth_service.dart';

class ApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {"Accept": "application/json"},
    ),
  )..interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        // If token expired (Laravel returns 401)
        if (error.response?.statusCode == 401) {
          final refreshed = await AuthService.refresh();

          if (refreshed) {
            // Retry original request with new token
            final newToken = await AppStorage.getAccessToken();
            error.requestOptions.headers["Authorization"] = "Bearer $newToken";

            final cloneReq = await dio.fetch(error.requestOptions);
            return handler.resolve(cloneReq);
          }

          // If refresh also failed → force logout
          await AuthService.logout();
        }

        return handler.next(error);
      },
    ));

  static void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }
}
