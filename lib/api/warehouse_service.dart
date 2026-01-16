import 'package:dio/dio.dart';
import 'http_client.dart';

/// Model untuk Warehouse
class Warehouse {
  final String id;
  final String code;
  final String name;
  final int priority;
  final bool isDeleted;

  Warehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.priority,
    required this.isDeleted,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      priority: json['priority'] ?? 0,
      isDeleted: json['is_deleted'] ?? false,
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
      
      final response = await ApiClient.dio.get('/warehouse/master');
      
      print('📦 Warehouse API response status: ${response.statusCode}');
      print('📦 Warehouse API response: ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final warehouses = data
            .map((json) => Warehouse.fromJson(json))
            .where((w) => !w.isDeleted) // Filter out deleted warehouses
            .toList();
        
        print('✅ Loaded ${warehouses.length} warehouses');
        return warehouses;
      }
      
      print('⚠️ Warehouse API returned success=false or non-200 status');
      return [];
    } on DioException catch (e) {
      print('❌ DioException fetching warehouses: ${e.message}');
      print('❌ Response status: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching warehouses: $e');
      return [];
    }
  }
}
