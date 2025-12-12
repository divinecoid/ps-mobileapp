class Product {
  final String sku;
  final String nama;
  final int qty;
  final Map<String, String> lokasi;
  final bool isScanned;
  final bool isReady;

  Product({
    required this.sku,
    required this.nama,
    required this.qty,
    required this.lokasi,
    this.isScanned = false,
    this.isReady = false,
  });
}
