import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/toast.dart';
import '../models/product.dart';
import '../models/scanned_item.dart';

class PrepareItemsScreen extends StatefulWidget {
  final List<Product> products;
  final Function(int, Product) onProductScanned;
  final Function(int) onProductReady;

  const PrepareItemsScreen({
    super.key,
    required this.products,
    required this.onProductScanned,
    required this.onProductReady,
  });

  @override
  State<PrepareItemsScreen> createState() => _PrepareItemsScreenState();
}

class _PrepareItemsScreenState extends State<PrepareItemsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MobileScannerController _scannerController;
  List<Product> _scannedProducts = [];
  List<ScannedItem> _scannedItems = []; // List semua item yang sudah di-scan dengan sequence
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Set initial tab ke 1 (Scanned Items)
    _tabController = TabController(initialIndex: 1, length: 2, vsync: this);
    // Initialize dengan produk yang sudah di-scan
    _scannedProducts = widget.products.where((p) => p.isScanned).toList();
    
    // Initialize scanner controller
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    
    // Listen to tab changes
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        // Tab Scan QR aktif, start scanner
        _scannerController.start();
        setState(() {
          _isScanning = true;
        });
      } else {
        // Tab Scanned Items aktif, stop scanner
        _scannerController.stop();
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // Extract sequence dari barcode (beberapa digit di belakang)
  String? _extractSequence(String barcode) {
    // Cari pattern sequence di akhir barcode (contoh: -001, -002, atau 001, 002)
    // Pattern: beberapa digit di akhir setelah separator atau langsung di akhir
    final regex = RegExp(r'[-_]?(\d{2,})$');
    final match = regex.firstMatch(barcode);
    if (match != null) {
      return match.group(1);
    }
    // Jika tidak ada pattern, ambil 3 digit terakhir
    if (barcode.length >= 3) {
      return barcode.substring(barcode.length - 3);
    }
    return null;
  }

  // Validasi sequence harus berbeda-beda untuk produk yang sama
  bool _isSequenceUnique(String sku, String sequence) {
    return !_scannedItems.any((item) => 
      item.sku == sku && item.sequence == sequence
    );
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (!_isScanning || _tabController.index != 0) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      final String? code = barcode.rawValue;

      if (code != null) {
        setState(() {
          _isScanning = false;
        });

        // Extract sequence dari barcode
        final sequence = _extractSequence(code);
        if (sequence == null) {
          Toast.show(context, 'Barcode tidak valid: sequence tidak ditemukan');
          setState(() {
            _isScanning = true;
          });
          return;
        }

        // Cari produk berdasarkan barcode/SKU
        bool productFound = false;
        for (int i = 0; i < widget.products.length; i++) {
          final product = widget.products[i];
          // Simulasi: jika barcode cocok dengan SKU atau nama produk
          if (code.contains(product.sku) || product.sku.contains(code) || 
              code.toUpperCase().contains(product.nama.toUpperCase().replaceAll(' ', ''))) {
            
            // Validasi sequence harus berbeda-beda
            if (!_isSequenceUnique(product.sku, sequence)) {
              Toast.show(context, 'Sequence $sequence sudah pernah di-scan untuk ${product.nama}');
              setState(() {
                _isScanning = true;
              });
              return;
            }

            // Cek apakah sudah mencapai qty maksimum
            final scannedCount = _scannedItems.where((item) => item.sku == product.sku).length;
            if (scannedCount >= product.qty) {
              Toast.show(context, 'Qty maksimum untuk ${product.nama} sudah tercapai (${product.qty})');
              setState(() {
                _isScanning = true;
              });
              return;
            }

            // Buat item code (contoh: BARANG A-001)
            final itemCode = '${product.nama.toUpperCase().replaceAll(' ', '')}-$sequence';

            // Simpan scanned item dengan sequence
            final scannedItem = ScannedItem(
              sku: product.sku,
              nama: product.nama,
              itemCode: itemCode,
              sequence: sequence,
              scannedAt: DateTime.now(),
            );

            setState(() {
              _scannedItems.add(scannedItem);
              
              // Update produk menjadi scanned jika belum ada scanned items sebelumnya
              if (scannedCount == 0) {
                final updatedProduct = Product(
                  sku: product.sku,
                  nama: product.nama,
                  qty: product.qty,
                  lokasi: product.lokasi,
                  isScanned: true,
                );
                widget.onProductScanned(i, updatedProduct);
                
                if (!_scannedProducts.any((p) => p.sku == product.sku)) {
                  _scannedProducts.add(updatedProduct);
                }
              }
            });

            Toast.show(context, '${product.nama} ($itemCode) berhasil di-scan');

            // Switch ke tab Scanned Items setelah scan
            _tabController.animateTo(1);
            productFound = true;
            return;
          }
        }

        if (!productFound) {
          Toast.show(context, 'Produk tidak ditemukan');
        }
        setState(() {
          _isScanning = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Siapkan Barang',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(Icons.qr_code_scanner),
              text: 'Scan QR',
            ),
            Tab(
              icon: Icon(Icons.checklist),
              text: 'Scanned Items',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Scan QR
          _buildScanQRTab(),
          // Tab 2: Scanned Items
          _buildScannedItemsTab(),
        ],
      ),
    );
  }

  Widget _buildScanQRTab() {
    return Stack(
      children: [
        // Camera Scanner
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcodeDetect,
        ),
        // Overlay dengan instruksi
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.3),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Top instruction
              SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Arahkan kamera ke barcode produk',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Spacer(),
              // Center scanning area
              Container(
                width: 300,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Corner indicators
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Scan type indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'BARCODE SCANNER',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              // Bottom instruction
              SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(height: 8),
                        Text(
                          'Scanner akan mendeteksi barcode secara otomatis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannedItemsTab() {
    // Group scanned items by SKU
    final Map<String, List<ScannedItem>> groupedItems = {};
    for (var item in _scannedItems) {
      if (!groupedItems.containsKey(item.sku)) {
        groupedItems[item.sku] = [];
      }
      groupedItems[item.sku]!.add(item);
    }

    // Tampilkan semua produk, termasuk yang belum di-scan
    if (widget.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada produk',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              final product = widget.products[index];
              // Ambil scanned items untuk produk ini, atau empty list jika belum ada
              final items = groupedItems[product.sku] ?? [];
              
              return _buildGroupedProductCard(product, items);
            },
          ),
        ),
        // Tombol Barang Siap Dikirim
        SafeArea(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Cek apakah semua produk sudah complete dan ready
                  final allReady = widget.products.every((p) => p.isReady);
                  if (allReady) {
                    Navigator.pop(context);
                    Toast.show(context, 'Barang siap dikirim');
                  } else {
                    Toast.show(context, 'Semua produk harus siap terlebih dahulu');
                  }
                },
                icon: Icon(Icons.send, size: 24),
                label: Text(
                  'BARANG SIAP DIKIRIM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedProductCard(Product product, List<ScannedItem> items) {
    final scannedCount = items.length;
    final targetQty = product.qty;
    final isComplete = scannedCount >= targetQty;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan nama produk dan progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nama,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SCANNED ITEM: $scannedCount/$targetQty',
                        style: TextStyle(
                          fontSize: 14,
                          color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isComplete)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade800, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'COMPLETE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // Rekomendasi Lokasi (hanya tampilkan jika belum fulfilled)
            if (!isComplete) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rekomendasi Lokasi: Lantai: ${product.lokasi['lantai']}, Ruang: ${product.lokasi['ruang']}, Rak: ${product.lokasi['rak']}, Bin: ${product.lokasi['bin']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            // List item codes yang sudah di-scan (hanya tampilkan jika ada)
            if (items.isNotEmpty) ...[
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildDismissibleItemCard(item, product, index);
              }).toList(),
            ] else ...[
              // Tampilkan pesan jika belum ada item yang di-scan
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum ada item yang di-scan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Tombol PRODUK SIAP jika sudah complete
            if (isComplete && !product.isReady) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final productIndex = widget.products.indexWhere((p) => p.sku == product.sku);
                    widget.onProductReady(productIndex);
                    Toast.show(context, 'Produk ${product.nama} ditandai siap');
                  },
                  icon: Icon(Icons.check),
                  label: Text('PRODUK SIAP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            if (product.isReady) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade800),
                    SizedBox(width: 8),
                    Text(
                      'PRODUK SIAP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDismissibleItemCard(ScannedItem item, Product product, int itemIndex) {
    return Dismissible(
      key: Key('${item.sku}-${item.sequence}-${item.scannedAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart, // Hanya bisa swipe ke kiri
      background: Container(
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        // Tampilkan konfirmasi dialog
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Hapus Item'),
            content: Text('Apakah Anda yakin ingin menghapus ${item.itemCode}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text('Hapus'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        // Hapus item dari list
        setState(() {
          _scannedItems.removeWhere((i) => 
            i.sku == item.sku && 
            i.sequence == item.sequence &&
            i.scannedAt == item.scannedAt
          );
        });

        // Update produk jika tidak ada scanned items lagi
        final remainingItems = _scannedItems.where((i) => i.sku == product.sku).length;
        if (remainingItems == 0) {
          final productIndex = widget.products.indexWhere((p) => p.sku == product.sku);
          if (productIndex != -1) {
            final updatedProduct = Product(
              sku: product.sku,
              nama: product.nama,
              qty: product.qty,
              lokasi: product.lokasi,
              isScanned: false,
            );
            widget.onProductScanned(productIndex, updatedProduct);
          }
        }

        Toast.show(context, '${item.itemCode} telah dihapus');
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code, color: Colors.blue.shade700, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.itemCode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Text(
                'Seq: ${item.sequence}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

