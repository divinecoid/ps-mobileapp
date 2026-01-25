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
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  )..interceptors.add(InterceptorsWrapper(onError: _onError));

  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_URL']!,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  static Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode != 401) {
      return handler.next(error);
    }

    if (error.requestOptions.path.contains(Endpoint.refresh)) {
      await _forceLogout();
      return handler.next(error);
    }

    if (_refreshCompleter != null) {
      final ok = await _refreshCompleter!.future;
      if (ok) {
        return _retry(error, handler);
      }
      return handler.next(error);
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await AppStorage.getRefreshToken();
      if (refreshToken == null) throw Exception('No refresh token');

      final res = await _refreshDio.post(
        Endpoint.refresh,
        data: {'refresh_token': refreshToken},
      );

      final newToken = res.data['token'];
      if (newToken == null) throw Exception('No token');

      await AppStorage.setAccessToken(newToken);
      setToken(newToken);

      _refreshCompleter!.complete(true);
      return _retry(error, handler);
    } catch (e) {
      _refreshCompleter!.complete(false);
      await _forceLogout();
      return handler.next(error);
    } finally {
      _refreshCompleter = null;
    }
  }

  static Future<void> _retry(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = Options(
      method: error.requestOptions.method,
      headers: error.requestOptions.headers,
    );

    final response = await dio.request(
      error.requestOptions.path,
      data: error.requestOptions.data,
      queryParameters: error.requestOptions.queryParameters,
      options: opts,
    );

    return handler.resolve(response);
  }

  static void setToken(String? token) {
    if (token == null || token.isEmpty) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  static Future<void> _forceLogout() async {
    await AppStorage.clear();
    AuthEventBus.notifyTokenExpired();
  }
}
