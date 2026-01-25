import 'package:dio/dio.dart';
import 'http_client.dart';

class OrderService {
  /// GET /order/ → Get all orders (with optional marketplace filter)
  static Future<List<Map<String, dynamic>>> getOrders({
    String? marketplaceId,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (marketplaceId != null && marketplaceId.isNotEmpty) {
        queryParams['marketplace_id'] = marketplaceId;
      }

      print('📡 Fetching orders with params: $queryParams');

      final response = await ApiClient.dio.get(
        '/order/',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      print('📦 Order full response: ${response.data}');
      print('📦 Response type: ${response.data.runtimeType}');

      // Handle various Laravel response structures
      if (response.data is Map) {
        final Map<String, dynamic> data = response.data;
        print('📦 Response keys: ${data.keys.toList()}');

        // Try different possible keys
        if (data.containsKey('trx_orders')) {
          print('✅ Using trx_orders key (${data['trx_orders'].length} items)');
          return List<Map<String, dynamic>>.from(data['trx_orders']);
        } else if (data.containsKey('data')) {
          print('✅ Using data key');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data.containsKey('orders')) {
          print('✅ Using orders key');
          return List<Map<String, dynamic>>.from(data['orders']);
        } else {
          print('⚠️ Unknown map structure, returning empty');
          return [];
        }
      } else if (response.data is List) {
        print('✅ Response is direct array (${response.data.length} items)');
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        print('❌ Unknown response type');
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
