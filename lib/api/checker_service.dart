import 'package:dio/dio.dart';
import 'endpoints.dart';
import 'http_client.dart';

class CheckerService {
  /// GET /checker/assigned-orders → Get all orders awaiting checker approval
  ///
  /// Parameters:
  /// - perPage: Number of items per page (default: 15)
  /// - page: Page number (default: 1)
  ///
  /// Returns:
  /// - Map containing paginated order data with checker status
  static Future<Map<String, dynamic>> getAssignedOrders({
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        Endpoint.checkerAssignedOrders,
        queryParameters: {'per_page': perPage, 'page': page},
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// GET /checker/search → Search orders by AWB, Serial, or Customer name
  ///
  /// Parameters:
  /// - search: Search query (AWB code, Serial Number, or Customer name)
  /// - marketplaceId: Filter by marketplace ID (optional)
  /// - perPage: Number of items per page (default: 15)
  /// - page: Page number (default: 1)
  ///
  /// Returns:
  /// - Map containing paginated search results
  static Future<Map<String, dynamic>> searchOrders({
    required String search,
    String? marketplaceId,
    int perPage = 15,
    int page = 1,
  }) async {
    try {
      final queryParams = {'search': search, 'per_page': perPage, 'page': page};

      if (marketplaceId != null && marketplaceId.isNotEmpty) {
        queryParams['marketplace_id'] = marketplaceId;
      }

      final response = await ApiClient.dio.get(
        '${Endpoint.checkerAssignedOrders.replaceAll('/assigned-orders', '')}/search',
        queryParameters: queryParams,
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  /// PATCH /checker/approve-order/{id} → Approve an order after checking
  ///
  /// Parameters:
  /// - orderId: UUID of the order to approve
  ///
  /// Returns:
  /// - Map containing success status, approved order data, and checker name
  static Future<Map<String, dynamic>> approveOrder(String orderId) async {
    return approveOrderWithScans(orderId, const []);
  }

  static Future<Map<String, dynamic>> getOrderItems(String orderId) async {
    try {
      final response = await ApiClient.dio.get(
        '${Endpoint.checkerOrderItems}/$orderId',
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getOrderBySerial(String serial) async {
    try {
      final response = await ApiClient.dio.get(
        '${Endpoint.checkerSearchBySerial}/${Uri.encodeComponent(serial)}',
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> validateProductBarcode({
    required String orderId,
    required String barcode,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        Endpoint.checkerValidateProductBarcode,
        data: {'order_id': orderId, 'barcode': barcode},
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        return Map<String, dynamic>.from(e.response!.data);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> approveOrderWithScans(
    String orderId,
    List<String> scannedBarcodes,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '${Endpoint.checkerApproveOrder}/$orderId',
        data: {'scanned_barcodes': scannedBarcodes},
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
