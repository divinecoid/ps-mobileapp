import 'package:dio/dio.dart';
import 'http_client.dart';

/// Model untuk Rack
class Rack {
  final String id;
  final String code;
  final String name;
  final String warehouseId;
  final String? warehouseName;
  final bool isDeleted;

  Rack({
    required this.id,
    required this.code,
    required this.name,
    required this.warehouseId,
    this.warehouseName,
    this.isDeleted = false,
  });

  factory Rack.fromJson(Map<String, dynamic> json) {
    return Rack(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse']?['name'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  /// Display name dengan format "code - name (warehouseName)"
  String get displayName {
    if (warehouseName != null) {
      return '$code - $name ($warehouseName)';
    }
    return '$code - $name';
  }

  /// Short display name dengan format "code - name"
  String get shortDisplayName => '$code - $name';

  @override
  String toString() => 'Rack(id: $id, code: $code, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Rack && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class RackService {
  /// Get all racks from the master data
  /// 
  /// Returns:
  /// - List of Rack objects
  static Future<List<Rack>> getRacks() async {
    try {
      final response = await ApiClient.dio.get('/rack/master');

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((json) => Rack.fromJson(json as Map<String, dynamic>))
            .where((rack) => !rack.isDeleted) // Filter out deleted racks
            .toList();
      }

      return [];
    } on DioException catch (e) {
      print('❌ Error fetching racks: ${e.message}');
      return [];
    } catch (e) {
      print('❌ Unexpected error fetching racks: $e');
      return [];
    }
  }

  /// Get racks filtered by warehouse ID
  /// 
  /// Parameters:
  /// - warehouseId: UUID of the warehouse to filter by
  /// 
  /// Returns:
  /// - List of Rack objects belonging to the specified warehouse
  static Future<List<Rack>> getRacksByWarehouse(String warehouseId) async {
    final allRacks = await getRacks();
    return allRacks.where((rack) => rack.warehouseId == warehouseId).toList();
  }
}
