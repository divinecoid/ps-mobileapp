import 'package:dio/dio.dart';
import 'http_client.dart';

class InboundService {
  /// Submit inbound receiving with array of barcodes
  /// 
  /// Parameters:
  /// - barcodes: List of barcode strings in format: CMT_CODE|REQUEST_DATE|MODEL_SKU|COLOR_CODE|SIZE_CODE|TYPE|SEQUENCE
  /// - warehouseId: UUID of the warehouse
  /// - notes: Optional notes for the receiving
  /// 
  /// Returns:
  /// - Map containing success status, message, data, and errors
  static Future<Map<String, dynamic>> submitInbound({
    required List<String> barcodes,
    required String warehouseId,
    String? notes,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/inbound',
        data: {
          'barcodes': barcodes,
          'warehouse_id': warehouseId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Successfully processed inbound',
        'data': response.data['data'],
        'errors': response.data['errors'] ?? [],
      };
    } on DioException catch (e) {
      // Handle different error types
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;

        if (statusCode == 422) {
          // Validation error
          return {
            'success': false,
            'message': responseData['message'] ?? 'Validation failed',
            'data': null,
            'errors': responseData['errors'] ?? {},
          };
        } else if (statusCode == 400) {
          // All barcodes failed
          return {
            'success': false,
            'message': responseData['message'] ?? 'All barcodes failed to parse',
            'data': null,
            'errors': responseData['errors'] ?? [],
          };
        } else if (statusCode == 500) {
          // Server error
          return {
            'success': false,
            'message': responseData['message'] ?? 'Failed to process inbound receiving',
            'data': null,
            'errors': [responseData['error']],
          };
        }
      }

      // Network or other errors
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
        'data': null,
        'errors': [e.message ?? 'Unknown error'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: $e',
        'data': null,
        'errors': [e.toString()],
      };
    }
  }
}
