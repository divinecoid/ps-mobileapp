import 'package:dio/dio.dart';
import 'http_client.dart';

class OrderService {
  /// GET /order/ → Get all orders
  static Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final response = await ApiClient.dio.get('/order/');
      
      // Handle response format dari Laravel
      // Biasanya Laravel return: { "data": [...] } atau langsung array
      if (response.data is Map && response.data.containsKey('data')) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      } else if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        return [];
      }
    } on DioException catch (e) {
      print('Error fetching orders: ${e.message}');
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
      }
      rethrow;
    }
  }

  /// GET /order/{id} → Get single order detail
  static Future<Map<String, dynamic>> getOrderDetail(String id) async {
    try {
      final response = await ApiClient.dio.get('/order/$id');
      
      // Handle response format dari Laravel
      if (response.data is Map && response.data.containsKey('data')) {
        return Map<String, dynamic>.from(response.data['data']);
      } else if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      print('Error fetching order detail: ${e.message}');
      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
      }
      rethrow;
    }
  }
}

