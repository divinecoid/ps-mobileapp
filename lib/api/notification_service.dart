import 'package:dio/dio.dart';
import 'endpoints.dart';
import 'http_client.dart';

class NotificationService {
  static Future<Map<String, dynamic>> getNotifications({int perPage = 100, int page = 1, bool unread = false}) async {
    try {
      final resp = await ApiClient.dio.get(
        Endpoint.notification,
        queryParameters: {'per_page': perPage, 'page': page, 'unread': unread ? 1 : 0},
      );
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      if (e.response != null) return Map<String, dynamic>.from(e.response!.data);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getLowStock() async {
    try {
      final resp = await ApiClient.dio.get(Endpoint.notificationLowStock);
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      if (e.response != null) return Map<String, dynamic>.from(e.response!.data);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> markAsRead(String id) async {
    try {
      final resp = await ApiClient.dio.patch('${Endpoint.notification}/$id/read');
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      if (e.response != null) return Map<String, dynamic>.from(e.response!.data);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createNotification({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final resp = await ApiClient.dio.post(
        Endpoint.notification,
        data: {
          'title': title,
          'message': message,
          'type': type,
          'data': data,
        },
      );
      return Map<String, dynamic>.from(resp.data);
    } on DioException catch (e) {
      if (e.response != null) return Map<String, dynamic>.from(e.response!.data);
      rethrow;
    }
  }
}
