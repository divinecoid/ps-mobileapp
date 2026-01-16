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
      final response = await ApiClient.dio.get('/warehouse/master');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((json) => Warehouse.fromJson(json))
            .where((w) => !w.isDeleted) // Filter out deleted warehouses
            .toList();
      }
      
      return [];
    } on DioException catch (e) {
      print('Error fetching warehouses: ${e.message}');
      return [];
    } catch (e) {
      print('Error fetching warehouses: $e');
      return [];
    }
  }
}
