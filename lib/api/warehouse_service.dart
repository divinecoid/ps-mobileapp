import 'package:dio/dio.dart';
import 'http_client.dart';

/// Model untuk Warehouse
class Warehouse {
  final String id;
  final String code;
  final String name;
  final int priority;
  final bool deleted_at;
  final String type;

  Warehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.priority,
    required this.deleted_at,
    required this.type,
  });

 factory Warehouse.fromJson(Map<String, dynamic> json) {
  return Warehouse(
    id: json['id'] ?? '',
    code: json['code'] ?? '',
    name: json['name'] ?? '',
    priority: int.tryParse(json['priority'].toString()) ?? 0,
    deleted_at: json['deleted_at'] == true,
      type: json['type'] ?? 'SMALL',
  );
}

  /// Display name with code
  String get displayName => '$code - $name';
}

/// Service untuk fetch warehouse master data
class WarehouseService {
  /// Fetch all warehouses from API
  static Future<List<Warehouse>> getWarehouses() async {
    try {
      print('🔄 Fetching warehouses from API...');
      
      final response = await ApiClient.dio.get(
        '/warehouse',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      print('📦 Warehouse API response status: ${response.statusCode}');
      print('📦 Warehouse API response: ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final warehouses = data
            .map((json) => Warehouse.fromJson(json))
            .where((w) => !w.deleted_at) // Filter out deleted warehouses
            .toList();
        
        print('✅ Loaded ${warehouses.length} warehouses');
        return warehouses;
      }
      
      print('⚠️ Warehouse API returned success=false or non-200 status');
      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching warehouses');
      print('❌ Error type: ${e.type}');
      print('❌ Error message: ${e.message}');
      print('❌ Response status: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');
      
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        print('⏱️ TIMEOUT: API took too long to respond');
      } else if (e.type == DioExceptionType.connectionError) {
        print('🔌 CONNECTION ERROR: Cannot reach server');
      } else if (e.response?.statusCode == 401) {
        print('🔒 UNAUTHORIZED: Token may be invalid or missing');
      }
      
      return [];
    } catch (e) {
      print('❌ Error fetching warehouses: $e');
      return [];
    }
  }
}
