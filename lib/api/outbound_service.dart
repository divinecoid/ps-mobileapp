import 'package:dio/dio.dart';
import 'endpoints.dart';
import 'http_client.dart';

class OutboundService {
  /// POST /outbound/validate-awb → Validate AWB code and get order details
  static Future<Map<String, dynamic>> validateAwb(String awbCode) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.outboundValidateAwb,
        data: {'awb_code': awbCode},
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        // Return error response from server
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// GET /outbound/order-items/{orderId} → Get order items expanded by quantity
  static Future<Map<String, dynamic>> getOrderItems(String orderId) async {
    try {
      final response = await ApiClient.dio.get(
        '${Endpoint.outboundOrderItems}/$orderId',
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }
}
