import 'package:dio/dio.dart';
import 'endpoints.dart';
import 'http_client.dart';

class OrderService {
  /// GET /order/ → Get all orders (with optional marketplace filter)
  static Future<List<Map<String, dynamic>>> getOrders({
    String? marketplaceId,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, dynamic>{
        if (marketplaceId != null && marketplaceId.isNotEmpty)
          'marketplace_id': marketplaceId,
      };

      final response = await ApiClient.dio.get(
        Endpoint.order,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      // Handle various Laravel response structures
      final data = response.data;

      if (data is Map && data.containsKey('data')) {
        return List<Map<String, dynamic>>.from(data['data']);
      }

      return [];
    } on DioException catch (e) {
      if (e.response != null) {}
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
      if (e.response != null) {}
      rethrow;
    }
  }

  /// POST /outbound/validate-product-barcode → Validate product barcode
  static Future<Map<String, dynamic>> validateProductBarcode(
    String barcode,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.outboundValidateProductBarcode,
        data: {'barcode': barcode},
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// POST /outbound/submit-preparation → Submit order preparation
  static Future<Map<String, dynamic>> submitPreparation({
    required String orderId,
    required String preparedAt,
    required List<String> scannedBarcodes,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.outboundSubmitPreparation,
        data: {
          'order_id': orderId,
          'prepared_at': preparedAt,
          'scanned_barcodes': scannedBarcodes,
        },
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// POST /outbound/assign-order → Assign order to me
  static Future<Map<String, dynamic>> assignOrder(String orderId) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.outboundAssignOrder,
        data: {'order_id': orderId},
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// POST /outbound/unassign-order → Unassign order
  static Future<Map<String, dynamic>> unassignOrder(String orderId) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.outboundUnassignOrder,
        data: {'order_id': orderId},
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception('Invalid response format');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// GET /outbound/assigned-orders → Get orders assigned to me
  static Future<List<Map<String, dynamic>>> getAssignedOrders() async {
    try {
      final response = await ApiClient.dio.get(Endpoint.outboundAssignedOrders);

      final data = response.data;

      if (data is Map && data.containsKey('data')) {
        return List<Map<String, dynamic>>.from(data['data']);
      }

      return [];
    } on DioException catch (e) {
      if (e.response != null) {}
      rethrow;
    }
  }
}
