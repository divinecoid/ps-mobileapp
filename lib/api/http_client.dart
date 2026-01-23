import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/secure_storage.dart';
import '../utils/auth_event_bus.dart';

class ApiClient {
  static Completer<bool>? _refreshCompleter;
  
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {"Accept": "application/json"},
    ),
  )..interceptors.add(InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        // Check if response has success: false with "Token expired" message
        if (response.data is Map && 
            response.data['success'] == false && 
            response.data['message']?.toString().toLowerCase().contains('token') == true) {
          print('⚠️ Token expired detected in response: ${response.data['message']}');
          
          // Clear storage and trigger logout
          AppStorage.clear();
          AuthEventBus.notifyTokenExpired();
          
          // Return error to prevent further processing
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: 'Token expired',
            ),
          );
        }
        
        return handler.next(response);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        // If token expired (Laravel returns 401)
        if (error.response?.statusCode == 401) {
          // Check if this is the refresh endpoint itself failing
          if (error.requestOptions.path.contains('/auth/refresh')) {
            print('❌ Refresh endpoint failed - clearing storage and redirecting to login');
            _refreshCompleter = null;
            await AppStorage.clear();
            AuthEventBus.notifyTokenExpired();
            return handler.next(error);
          }
          
          // If already refreshing, wait for the existing refresh to complete
          if (_refreshCompleter != null) {
            print('⏳ Waiting for ongoing refresh to complete...');
            try {
              final refreshed = await _refreshCompleter!.future;
              
              if (refreshed) {
                print('✅ Using refreshed token, retrying request');
                final newToken = await AppStorage.getAccessToken();
                error.requestOptions.headers["Authorization"] = "Bearer $newToken";
                final cloneReq = await dio.fetch(error.requestOptions);
                return handler.resolve(cloneReq);
              } else {
                print('❌ Refresh failed, rejecting request');
                return handler.next(error);
              }
            } catch (e) {
              print('❌ Error waiting for refresh: $e');
              return handler.next(error);
            }
          }
          
          // Start new refresh process
          print('⚠️ 401 Unauthorized - attempting token refresh');
          _refreshCompleter = Completer<bool>();
          
          try {
            // Try to refresh token
            final refreshToken = await AppStorage.getRefreshToken();
            if (refreshToken == null) {
              print('❌ No refresh token found');
              _refreshCompleter!.complete(false);
              await AppStorage.clear();
              AuthEventBus.notifyTokenExpired();
              return handler.next(error);
            }
            
            final response = await dio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );
            
            if (response.data['token'] != null) {
              final newAccessToken = response.data['token'];
              await AppStorage.setAccessToken(newAccessToken);
              setToken(newAccessToken);
              
              _refreshCompleter!.complete(true);
              print('✅ Token refreshed successfully, retrying request');
              
              error.requestOptions.headers["Authorization"] = "Bearer $newAccessToken";
              final cloneReq = await dio.fetch(error.requestOptions);
              return handler.resolve(cloneReq);
            } else {
              print('❌ Token refresh failed - no token in response');
              _refreshCompleter!.complete(false);
              await AppStorage.clear();
              AuthEventBus.notifyTokenExpired();
            }
          } catch (e) {
            print('❌ Exception during refresh: $e');
            _refreshCompleter!.completeError(e);
            await AppStorage.clear();
            AuthEventBus.notifyTokenExpired();
          } finally {
            // Reset completer after a short delay
            Future.delayed(Duration(milliseconds: 100), () {
              _refreshCompleter = null;
            });
          }
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
