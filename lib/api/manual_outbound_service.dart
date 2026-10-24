import 'package:dio/dio.dart';
import 'http_client.dart';

class ManualOutboundService {
  static Map<String, dynamic> _error(DioException e, String fallback) {
    if (e.response != null && e.response!.data is Map) {
      final responseData = e.response!.data as Map;
      return {
        'success': false,
        'message': responseData['message'] ?? fallback,
        'data': responseData['data'],
      };
    }
    return {'success': false, 'message': 'Network error: ${e.message}'};
  }

  /// POST /outbound-manual/validate-barcode
  /// Hanya barcode piece (|P|) yang valid. data['product'] berisi model/color/size/rack.
  static Future<Map<String, dynamic>> validateBarcode(String barcode) async {
    try {
      final response = await ApiClient.dio.post(
        '/outbound-manual/validate-barcode',
        data: {'barcode': barcode},
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _error(e, 'Barcode tidak valid');
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  /// POST /outbound-manual/submit
  static Future<Map<String, dynamic>> submit({
    required List<String> barcodes,
    String? marketplaceId,
    String? notes,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/outbound-manual/submit',
        data: {
          'barcodes': barcodes,
          if (marketplaceId != null && marketplaceId.isNotEmpty)
            'marketplace_id': marketplaceId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Outbound manual berhasil',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      return _error(e, 'Gagal memproses outbound manual');
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  /// GET /outbound-manual → riwayat
  static Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        '/outbound-manual',
        queryParameters: {'page': page, 'limit': limit},
      );
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _error(e, 'Gagal memuat riwayat');
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }

  /// GET /outbound-manual/{id}
  static Future<Map<String, dynamic>> getDetail(String id) async {
    try {
      final response = await ApiClient.dio.get('/outbound-manual/$id');
      return {'success': true, 'data': response.data['data']};
    } on DioException catch (e) {
      return _error(e, 'Gagal memuat detail');
    } catch (e) {
      return {'success': false, 'message': 'Unexpected error: $e'};
    }
  }
}
