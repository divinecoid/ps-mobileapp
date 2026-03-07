import 'package:dio/dio.dart';
import 'http_client.dart';

class InboundService {
  /// Validate a single barcode before adding to scan list
  /// 
  /// Parameters:
  /// - barcode: Barcode string to validate
  /// 
  /// Returns:
  /// - Map containing success status, parsed data (cmt, model, color, size, is_dozen), or error message
  static Future<Map<String, dynamic>> validateBarcode(String barcode) async {
    try {
      final response = await ApiClient.dio.post(
        '/inbound/validate',
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

  /// Submit inbound receiving with separate arrays for dozen, piece, and rejected barcodes
  /// 
  /// Parameters:
  /// - barcodesDozens: List of barcode strings for dozen items
  /// - barcodesPieces: List of objects containing barcode and rack_id for piece items
  /// - barcodesRejected: List of barcode strings for rejected/BS items
  /// - warehouseId: UUID of the warehouse (required if barcodesDozens is not empty)
  /// - notes: Optional notes for the receiving
  /// 
  /// Returns:
  /// - Map containing success status, message, data, and errors
  static Future<Map<String, dynamic>> submitInbound({
    List<String>? barcodesDozens,
    List<Map<String, dynamic>>? barcodesPieces,
    List<String>? barcodesRejected,
    String? warehouseId,
    String? notes,
  }) async {
    // Validate that at least one of barcodes arrays is provided
    final hasDozen = barcodesDozens != null && barcodesDozens.isNotEmpty;
    final hasPiece = barcodesPieces != null && barcodesPieces.isNotEmpty;
    final hasRejected = barcodesRejected != null && barcodesRejected.isNotEmpty;
    
    if (!hasDozen && !hasPiece && !hasRejected) {
      return {
        'success': false,
        'message': 'Minimal salah satu dari barcodes_dozen, barcodes_piece, atau barcodes_rejected harus diisi',
        'data': null,
        'errors': [],
      };
    }

    // Validate warehouse_id if there are dozen barcodes
    if (hasDozen && (warehouseId == null || warehouseId.isEmpty)) {
      return {
        'success': false,
        'message': 'Warehouse harus dipilih untuk penerimaan dozen',
        'data': null,
        'errors': [],
      };
    }

    try {
      final Map<String, dynamic> requestData = {};
      
      if (hasDozen) {
        requestData['barcodes_dozen'] = barcodesDozens;
        requestData['warehouse_id'] = warehouseId;
      }
      
      if (hasPiece) {
        requestData['barcodes_piece'] = barcodesPieces;
      }
      
      if (hasRejected) {
        requestData['barcodes_rejected'] = barcodesRejected;
      }
      
      // Always send notes, even if empty (backend might expect it)
      requestData['notes'] = notes ?? '';

      final response = await ApiClient.dio.post(
        '/inbound',
        data: requestData,
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Successfully processed inbound',
        'data': response.data['data'],
        'errors': [],
      };
    } on DioException catch (e) {
      // Handle different error types
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final responseData = e.response!.data;

        if (statusCode == 422) {
          // Validation error with invalid barcodes info
          return {
            'success': false,
            'message': responseData['message'] ?? 'Validation failed',
            'data': responseData['data'],
            'errors': responseData['data']?['invalid'] ?? {},
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

  /// Get all inbound receiving records with pagination
  static Future<Map<String, dynamic>> getInbounds({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/inbound',
        queryParameters: {
          'page': page,
          'per_page': limit,
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
          'message': e.response!.data['message'] ?? 'Failed to fetch inbounds',
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

  /// Get inbound detail by ID
  static Future<Map<String, dynamic>> getInboundById(String id) async {
    try {
      final response = await ApiClient.dio.get('/inbound/$id');

      return {
        'success': true,
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 404) {
          return {
            'success': false,
            'message': 'Inbound tidak ditemukan',
          };
        }
        return {
          'success': false,
          'message': e.response!.data['message'] ?? 'Failed to fetch inbound',
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

  /// Generate next piece barcode by scanning any existing barcode of the product
  static Future<Map<String, dynamic>> generateNextBarcode(String barcode) async {
    try {
      final response = await ApiClient.dio.post(
        '/inbound/generate-next',
        data: {
          'barcode': barcode,
        },
      );

      return {
        'success': true,
        'data': response.data['data'],
        'message': response.data['message'],
      };
    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response!.data;
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal generate barcode',
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
