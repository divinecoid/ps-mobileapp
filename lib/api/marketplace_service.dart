import 'package:dio/dio.dart';
import 'http_client.dart';
import 'endpoints.dart';

class MarketplaceService {
  /// GET /marketplace → Get all marketplaces
  static Future<List<Map<String, dynamic>>> getMarketplaces() async {
    try {
      final response = await ApiClient.dio.get(Endpoint.marketplace);

      print('📦 Marketplace full response: ${response.data}');
      print('📦 Response type: ${response.data.runtimeType}');

      // Handle various Laravel response structures
      if (response.data is Map) {
        final Map<String, dynamic> data = response.data;
        print('📦 Response keys: ${data.keys.toList()}');

        // Try different possible keys
        if (data.containsKey('mdx_marketplaces')) {
          print('✅ Using mdx_marketplaces key');
          return List<Map<String, dynamic>>.from(data['mdx_marketplaces']);
        } else if (data.containsKey('data')) {
          print('✅ Using data key');
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data.containsKey('marketplaces')) {
          print('✅ Using marketplaces key');
          return List<Map<String, dynamic>>.from(data['marketplaces']);
        } else {
          // If map but no known key, maybe it's a single item?
          print('⚠️ Unknown map structure, returning empty');
          return [];
        }
      } else if (response.data is List) {
        print('✅ Response is direct array');
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        print('❌ Unknown response type');
        return [];
      }
    } on DioException catch (e) {
      print('❌ Error fetching marketplaces: ${e.message}');
      if (e.response != null) {
        print('   - Status: ${e.response?.statusCode}');
        print('   - Data: ${e.response?.data}');
      }
      rethrow;
    }
  }
}
