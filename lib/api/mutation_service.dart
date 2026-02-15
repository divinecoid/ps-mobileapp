import 'package:dio/dio.dart';
import 'http_client.dart';

class MutationService {
  /// Validate a barcode for mutation
  /// 
  /// Parameters:
  /// - barcode: Barcode string to validate
  /// 
  /// Returns:
  /// - Map containing success status and parsed data
  static Future<Map<String, dynamic>> validateBarcode(String barcode) async {
    try {
      final response = await ApiClient.dio.post(
        '/mutation/validate',
        data: {
          'barcode': barcode,
        },
      );

      return {
        'success': true,
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response!.data;
        return {
          'success': false,
          'message': responseData['message'] ?? 'Barcode tidak valid',
        };
      }
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: $e',
      };
    }
  }

  /// Submit mutation data
  /// 
  /// Parameters:
  /// - items: List of objects containing rack_id and barcodes array
  /// - notes: Optional notes
  /// 
  /// Returns:
  /// - Map containing success status, message, and data
  static Future<Map<String, dynamic>> submitMutation({
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    if (items.isEmpty) {
      return {
        'success': false,
        'message': 'Minimal satu item harus diisi',
        'data': null,
      };
    }

    try {
      final response = await ApiClient.dio.post(
        '/mutation',
        data: {
          'items': items,
          'notes': notes ?? '',
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Mutation processed successfully',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response!.data;
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to process mutation',
          'data': responseData['data'],
        };
      }
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: $e',
      };
    }
  }

  /// Get mutations history
  static Future<Map<String, dynamic>> getMutations({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/mutation',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null) 'search': search,
        },
      );

      return {
        'success': true,
        'data': response.data['data'],
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'success': false,
          'message': e.response!.data['message'] ?? 'Failed to fetch mutations',
        };
      }
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: $e',
      };
    }
  }
}
