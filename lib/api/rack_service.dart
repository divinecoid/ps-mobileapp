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

/// Satu baris stok di rak (model + warna + ukuran)
class RackStockItem {
  final String model;
  final String color;
  final String size;
  final int quantity;

  RackStockItem({
    required this.model,
    required this.color,
    required this.size,
    required this.quantity,
  });

  factory RackStockItem.fromJson(Map<String, dynamic> json) {
    return RackStockItem(
      model: json['model'] as String? ?? '-',
      color: json['color'] as String? ?? '-',
      size: json['size'] as String? ?? '-',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Hasil cek stok untuk satu rak
class RackStock {
  final String code;
  final String name;
  final String? warehouse;
  final List<RackStockItem> items;
  final int total;

  RackStock({
    required this.code,
    required this.name,
    this.warehouse,
    required this.items,
    required this.total,
  });

  factory RackStock.fromJson(Map<String, dynamic> json) {
    final rack = json['rack'] as Map<String, dynamic>;
    return RackStock(
      code: rack['code'] as String,
      name: rack['name'] as String,
      warehouse: rack['warehouse'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => RackStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class RackService {
  /// Ambil stok rak berdasarkan kode rak (hasil scan QR).
  /// Melempar [String] berisi pesan error yang siap ditampilkan.
  static Future<RackStock> getStockByCode(String code) async {
    try {
      final response = await ApiClient.dio.get(
        '/rack-stock',
        queryParameters: {'code': code},
      );
      if (response.data['success'] == true) {
        return RackStock.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw response.data['message']?.toString() ?? 'Gagal memuat stok';
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw 'Rak tidak ditemukan';
      throw 'Gagal memuat stok rak. Periksa koneksi Anda.';
    }
  }

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

  /// Get a single rack by its exact code
  /// 
  /// Parameters:
  /// - code: Exact rack code to search for
  /// 
  /// Returns:
  /// - Rack object if found, null otherwise
  static Future<Rack?> getRackByCode(String code) async {
    try {
      final response = await ApiClient.dio.get(
        '/rack',
        queryParameters: {'code': code},
      );

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        if (data.isNotEmpty) {
          final rack = Rack.fromJson(data.first as Map<String, dynamic>);
          if (!rack.isDeleted) {
            return rack;
          }
        }
      }

      return null;
    } on DioException catch (e) {
      print('❌ Error fetching rack by code: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Unexpected error fetching rack by code: $e');
      return null;
    }
  }
}
