class ScannedBarcode {
  final String barcode;
  final String sku;
  final String color;
  final String size;
  final DateTime scannedAt;

  ScannedBarcode({
    required this.barcode,
    required this.sku,
    required this.color,
    required this.size,
    required this.scannedAt,
  });

  // Parse barcode format: {code_cmt}|{timestamp}|{sku}|{code_color}|{code_size}|{group_or_piece}|{piece_numbering}
  static ScannedBarcode? fromBarcode(String barcode) {
    final parts = barcode.split('|');

    if (parts.length != 7) {
      return null;
    }

    return ScannedBarcode(
      barcode: barcode,
      sku: parts[2],
      color: parts[3],
      size: parts[4],
      scannedAt: DateTime.now(),
    );
  }

  bool isPiece() {
    final type = barcode.split('|')[5].trim();
    return type == 'PIECE' || type == 'P';
  }

  // Validate if barcode matches expected variant
  bool matchesVariant(
    String expectedSku,
    String expectedColor,
    String expectedSize,
  ) {
    return sku == expectedSku && color == expectedColor && size == expectedSize;
  }
}
