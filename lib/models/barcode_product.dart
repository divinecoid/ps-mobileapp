/// Tipe barcode yang tersedia
enum BarcodeType {
  lusin, // Barcode lusin (mewakili 12 item)
  satuan, // Barcode satuan/pcs (mewakili 1 item)
}

/// Model untuk barcode product yang akan discan saat inbound
class BarcodeProduct {
  /// Barcode unik untuk barcode ini
  final String barcode;
  
  /// Tipe barcode (lusin atau satuan)
  final BarcodeType type;
  
  /// Model baju (contoh: LENGAN PANJANG KERAH)
  final String model;
  
  /// Warna baju (contoh: Merah)
  final String warna;
  
  /// Size baju (contoh: S, M, L)
  final String size;
  
  /// Rak tempat penyimpanan dari CMT (contoh: RAK01, RAK A, RAK B)
  /// Per warna di model punya rak sendiri sesuai master data
  /// 1 Rak bisa banyak warna dan 1 warna bisa banyak Rak
  final String rak;
  
  /// Rack ID untuk piece items - UUID yang dipilih user saat scan
  /// Diperlukan untuk barcodes_piece saat submit ke API
  final String? rackId;
  
  /// Rack Code untuk piece items
  final String? rackCode;
  
  /// Jumlah item yang diwakili oleh barcode ini
  /// - Untuk lusin: biasanya 12, tapi bisa kurang jika sisa
  /// - Untuk satuan: selalu 1
  final int qty;
  
  /// Status apakah barcode sudah discan atau belum
  final bool isScanned;
  
  /// Waktu scan (null jika belum discan)
  final DateTime? scannedAt;

  /// Request ID yang terkait dengan barcode ini
  final String? requestId;

  /// Status apakah item ini reject (BS - Barang Rusak)
  final bool isReject;

  BarcodeProduct({
    required this.barcode,
    required this.type,
    required this.model,
    required this.warna,
    required this.size,
    required this.rak,
    this.rackId,
    this.rackCode,
    required this.qty,
    this.isScanned = false,
    this.scannedAt,
    this.requestId,
    this.isReject = false,
  });

  /// Copy with method untuk update status scanned
  BarcodeProduct copyWith({
    String? barcode,
    BarcodeType? type,
    String? model,
    String? warna,
    String? size,
    String? rak,
    String? rackId,
    String? rackCode,
    int? qty,
    bool? isScanned,
    DateTime? scannedAt,
    String? requestId,
    bool? isReject,
  }) {
    return BarcodeProduct(
      barcode: barcode ?? this.barcode,
      type: type ?? this.type,
      model: model ?? this.model,
      warna: warna ?? this.warna,
      size: size ?? this.size,
      rak: rak ?? this.rak,
      rackId: rackId ?? this.rackId,
      rackCode: rackCode ?? this.rackCode,
      qty: qty ?? this.qty,
      isScanned: isScanned ?? this.isScanned,
      scannedAt: scannedAt ?? this.scannedAt,
      requestId: requestId ?? this.requestId,
      isReject: isReject ?? this.isReject,
    );
  }

  /// Method untuk mark sebagai scanned
  BarcodeProduct markAsScanned() {
    return copyWith(
      isScanned: true,
      scannedAt: DateTime.now(),
    );
  }

  /// Method untuk mark sebagai belum scanned
  BarcodeProduct markAsUnscanned() {
    return copyWith(
      isScanned: false,
      scannedAt: null,
    );
  }

  /// Getter untuk label tipe barcode
  String get typeLabel {
    return type == BarcodeType.lusin ? 'Lusin' : 'Satuan';
  }

  /// Getter untuk display name (Model - Warna - Size)
  String get displayName {
    return '$model - $warna - $size';
  }

  /// Getter untuk display name dengan rak (Model - Warna - Size - Rak)
  String get displayNameWithRak {
    return '$model - $warna - $size - $rak';
  }

  /// Convert to JSON untuk serialization
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'type': type.name,
      'model': model,
      'warna': warna,
      'size': size,
      'rak': rak,
      'rackId': rackId,
      'rackCode': rackCode,
      'qty': qty,
      'isScanned': isScanned,
      'scannedAt': scannedAt?.toIso8601String(),
      'requestId': requestId,
      'isReject': isReject,
    };
  }

  /// Create from JSON
  factory BarcodeProduct.fromJson(Map<String, dynamic> json) {
    return BarcodeProduct(
      barcode: json['barcode'] as String,
      type: BarcodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BarcodeType.satuan,
      ),
      model: json['model'] as String,
      warna: json['warna'] as String,
      size: json['size'] as String,
      rak: json['rak'] as String,
      rackId: json['rackId'] as String?,
      rackCode: json['rackCode'] as String?,
      qty: json['qty'] as int,
      isScanned: json['isScanned'] as bool? ?? false,
      scannedAt: json['scannedAt'] != null
          ? DateTime.parse(json['scannedAt'] as String)
          : null,
      requestId: json['requestId'] as String?,
      isReject: json['isReject'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'BarcodeProduct(barcode: $barcode, type: $typeLabel, model: $model, warna: $warna, size: $size, rak: $rak, qty: $qty, isScanned: $isScanned)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BarcodeProduct && other.barcode == barcode;
  }

  @override
  int get hashCode => barcode.hashCode;
}

// ============================================
// CONTOH PENGGUNAAN
// ============================================

/*
// Contoh 1: Barcode Lusin untuk Size S (mewakili 12 item)
// Format baru: CMT|TIMESTAMP|MODEL|COLOR|SIZE|TYPE|SEQ
final barcodeLusin1 = BarcodeProduct(
  barcode: 'CMT01|20260116173826|LP|RED|S|D|1',
  type: BarcodeType.lusin,
  model: 'LENGAN PANJANG',
  warna: 'Red',
  size: 'S',
  rak: 'RAK01', // Rak yang dipilih saat request
  qty: 12, // 1 lusin = 12 item
  requestId: 'REQ-CMT01-20260116173826',
);

// Contoh 2: Barcode Satuan untuk Size S
final barcodeSatuanS = BarcodeProduct(
  barcode: 'CMT01|20260116173826|LP|RED|S|P|1',
  type: BarcodeType.satuan,
  model: 'LENGAN PANJANG',
  warna: 'Red',
  size: 'S',
  rak: 'RAK01',
  qty: 1, // 1 satuan = 1 item
  requestId: 'REQ-CMT01-20260116173826',
);

// Contoh penggunaan:
print(barcodeLusin1.displayName); // Output: LENGAN PANJANG KERAH - Merah - S
print(barcodeLusin1.displayNameWithRak); // Output: LENGAN PANJANG KERAH - Merah - S - RAK01
print(barcodeLusin1.typeLabel); // Output: Lusin
print(barcodeLusin1.rak); // Output: RAK01
print(barcodeLusin1.toString()); // Output: BarcodeProduct(...)

// Mark sebagai scanned setelah discan
final scannedBarcode = barcodeLusin1.markAsScanned();
print(scannedBarcode.isScanned); // Output: true
print(scannedBarcode.scannedAt); // Output: DateTime object

// Convert to JSON
final json = barcodeLusin1.toJson();
print(json);

// Create from JSON
final fromJson = BarcodeProduct.fromJson(json);
print(fromJson);
*/

