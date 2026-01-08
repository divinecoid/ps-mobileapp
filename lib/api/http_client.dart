import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/secure_storage.dart';
import 'auth_service.dart';

class ApiClient {
  static String _normalizeBaseUrl(String? url) {
    if (url == null || url.isEmpty) {
      throw Exception('API_URL tidak ditemukan di .env file');
    }
    
    // Trim whitespace
    url = url.trim();
    
    // Jika URL tidak memiliki scheme, tambahkan http://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Extract host (sebelum : atau /)
      final hostPart = url.split(':').first.split('/').first;
      
      // Untuk localhost/127.0.0.1/10.0.2.2/IP address, gunakan http://
      final isLocalOrIP = hostPart == 'localhost' || 
          hostPart == '127.0.0.1' || 
          hostPart == '10.0.2.2' ||
          RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(hostPart);
      
      if (isLocalOrIP) {
        url = 'http://$url';
      } else {
        // Default ke https:// untuk production domain
        url = 'https://$url';
      }
    }
    
    // Pastikan URL tidak berakhir dengan slash (kecuali jika ada path seperti /api)
    // Hapus trailing slash hanya jika tidak ada path
    if (url.endsWith('/') && !url.contains('/api')) {
      url = url.substring(0, url.length - 1);
    }
    
    // Normalize: pastikan tidak ada double slash kecuali setelah scheme
    url = url.replaceAll(RegExp(r'(?<!:)/+'), '/');
    
    return url;
  }

  static Dio? _dioInstance;
  
  static Dio get dio {
    if (_dioInstance == null) {
      final apiUrl = dotenv.env['API_URL'];
      print('API_URL from .env: $apiUrl');
      
      final normalizedUrl = _normalizeBaseUrl(apiUrl);
      print('Normalized API URL: $normalizedUrl');
      
      _dioInstance = Dio(
        BaseOptions(
          baseUrl: normalizedUrl,
          headers: {"Accept": "application/json"},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
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
    }
    return _dioInstance!;
  }

  static void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }
  
  static void reset() {
    _dioInstance = null;
  }
}
