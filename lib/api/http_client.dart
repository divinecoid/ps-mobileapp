import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/secure_storage.dart';
import '../utils/auth_event_bus.dart';
import 'endpoints.dart';

class ApiClient {
  static Completer<bool>? _refreshCompleter;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  )..interceptors.add(InterceptorsWrapper(onError: _onError));

  /// Dio khusus refresh token (NO interceptor)
  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {'Accept': 'application/json'},
    ),
  );

  /// Global error handler
  static Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode != 401) {
      return handler.next(error);
    }

    final path = error.requestOptions.path;

    // Kalau refresh sendiri gagal → logout paksa
    if (path.contains(Endpoint.refresh)) {
      await _forceLogout();
      return handler.next(error);
    }

    // Kalau ada refresh ongoing → tunggu
    if (_refreshCompleter != null) {
      try {
        final success = await _refreshCompleter!.future;
        if (success) {
          final newToken = await AppStorage.getAccessToken();
          error.requestOptions.headers['Authorization'] = 'Bearer $newToken';

          final retry = await dio.fetch(error.requestOptions);
          return handler.resolve(retry);
        }
      } catch (_) {}
      return handler.next(error);
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await AppStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        await _forceLogout();
        return handler.next(error);
      }

      final response = await _refreshDio.post(
        Endpoint.refresh,
        data: {'refresh_token': refreshToken},
      );

      final newToken = response.data['token'];
      if (newToken == null) {
        _refreshCompleter!.complete(false);
        await _forceLogout();
        return handler.next(error);
      }

      await AppStorage.setAccessToken(newToken);
      setToken(newToken);

      _refreshCompleter!.complete(true);

      error.requestOptions.headers['Authorization'] = 'Bearer $newToken';

      final retry = await dio.fetch(error.requestOptions);
      return handler.resolve(retry);
    } catch (e) {
      _refreshCompleter!.completeError(e);
      await _forceLogout();
      return handler.next(error);
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Set Authorization header global
  static void setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear auth & notify UI
  static Future<void> _forceLogout() async {
    await AppStorage.clear();
    AuthEventBus.notifyTokenExpired();
  }
}
