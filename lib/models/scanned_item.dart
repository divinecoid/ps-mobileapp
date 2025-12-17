class ScannedItem {
  final String sku;
  final String nama;
  final String itemCode; // Barcode dengan sequence (contoh: BARANG A-001)
  final String sequence; // Sequence number (contoh: 001)
  final DateTime scannedAt;

  ScannedItem({
    required this.sku,
    required this.nama,
    required this.itemCode,
    required this.sequence,
    required this.scannedAt,
  });
}
