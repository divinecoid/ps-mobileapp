import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import '../components/loading.dart';
import '../components/toast.dart';
import '../components/app_drawer.dart';
import 'inbound_screen.dart';
import 'reject_screen.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  // State management
  String? _scannedResiNumber;
  bool _isScanningResi = false;
  bool _isScanningProduct = false;
  List<Product> _products = [];
  Set<String> _scannedProductSkus = {};

  // Data dummy resi
  final Map<String, dynamic> _dummyResiData = {
    'resiNumber': 'YKART',
    'marketplace': 'Shopee',
    'kurir': 'J&T Express',
    'penerima': 'Pembeli Shopee',
    'noHp': '62812345678910',
    'alamat': 'Jl. Bangka IV No.126 MAMPANG PRAPATAN, KOTA JAKARTA SELATAN, DKI JAKARTA',
    'berat': '2100 gr',
    'batasKirim': '31-12-2024',
  };

  // Data dummy produk
  final List<Map<String, dynamic>> _dummyProducts = [
    {
      'sku': 'PL-MAR-XL',
      'nama': 'POLO Maroon XL',
      'qty': 1,
      'lokasi': {
        'lantai': '1',
        'ruang': 'A',
        'rak': '011',
        'bin': '01',
      },
    },
    {
      'sku': 'ON-WHT-S',
      'nama': 'O-Neck Putih S',
      'qty': 1,
      'lokasi': {
        'lantai': '2',
        'ruang': 'B',
        'rak': '021',
        'bin': '02',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startScanResi() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          title: 'Scan Resi',
          instruction: 'Arahkan kamera ke barcode resi marketplace',
          scanType: ScanType.barcode,
          onScanResult: (barcode) {
            // Callback dipanggil saat barcode terdeteksi
            // Dalam implementasi nyata, barcode akan digunakan untuk fetch data resi
          },
        ),
      ),
    );

    // Set data resi setelah scan (menggunakan data dummy)
    // Dalam implementasi nyata, result (barcode) akan digunakan untuk fetch data
    // Untuk demo, selalu set data dummy meskipun result null
    if (mounted) {
      setState(() {
        _scannedResiNumber = _dummyResiData['resiNumber'];
        _products = _dummyProducts.map((p) => Product(
          sku: p['sku'],
          nama: p['nama'],
          qty: p['qty'],
          lokasi: p['lokasi'],
          isScanned: false,
        )).toList();
      });

      if (mounted) {
        Toast.show(context, 'Resi berhasil di-scan');
      }
    }
  }

  Future<void> _startScanProduct(int productIndex) async {
    if (productIndex >= _products.length) return;

    final product = _products[productIndex];
    
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          title: 'Scan Produk',
          instruction: 'Arahkan kamera ke barcode produk',
          scanType: ScanType.barcode,
          onScanResult: (barcode) {
            // Callback dipanggil saat barcode terdeteksi
            // Dalam implementasi nyata, barcode akan divalidasi dengan SKU produk
          },
        ),
      ),
    );

    // Validasi barcode dengan SKU produk (simulasi)
    // Dalam implementasi nyata, result akan divalidasi dengan SKU
    if (result != null || mounted) {
      setState(() {
        _products[productIndex] = Product(
          sku: product.sku,
          nama: product.nama,
          qty: product.qty,
          lokasi: product.lokasi,
          isScanned: true,
        );
        _scannedProductSkus.add(product.sku);
      });

      if (mounted) {
        Toast.show(context, 'Produk ${product.nama} berhasil di-scan');
      }
    }
  }

  void _markProductReady(int productIndex) {
    setState(() {
      _products[productIndex] = Product(
        sku: _products[productIndex].sku,
        nama: _products[productIndex].nama,
        qty: _products[productIndex].qty,
        lokasi: _products[productIndex].lokasi,
        isScanned: _products[productIndex].isScanned,
        isReady: true,
      );
    });
  }

  void _markResiReady() {
    final allProductsReady = _products.every((p) => p.isReady);
    if (!allProductsReady) {
      Toast.show(context, 'Semua produk harus siap terlebih dahulu');
      return;
    }

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resi berhasil diproses dan siap dikirim!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Total Produk: ${_products.length} item',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: SIAP KIRIM',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset state untuk scan resi baru
                setState(() {
                  _scannedResiNumber = null;
                  _products = [];
                  _scannedProductSkus = {};
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleMenuSelection(String menu) {
    switch (menu) {
      case 'outbound':
        // Already on outbound screen
        break;
      case 'inbound':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InboundScreen()),
        );
        break;
      case 'reject':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RejectScreen()),
        );
        break;
      case 'daily_statistics':
        // TODO: Navigate to daily statistics screen
        break;
      case 'stock_opname':
        // TODO: Navigate to stock opname screen
        break;
      case 'mutasi':
        // TODO: Navigate to mutasi screen
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'PREPARIST APP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        onMenuSelected: _handleMenuSelection,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: _scannedResiNumber == null
              ? _buildScanResiView()
              : _buildResiDataView(),
        ),
      ),
    );
  }

  Widget _buildScanResiView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card: Scan Resi Marketplace
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Scan Resi Marketplace',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Langkah: Scan resi → Ambil produk → Scan produk → Resi siap',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Card: Step 1 - Scan Resi
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.qr_code_scanner, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Scan Resi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _scannedResiNumber ?? 'Belum ada resi di-scan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _startScanResi,
                      icon: Icon(Icons.qr_code_scanner),
                      label: Text('SCAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResiDataView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card: Data Resi
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Data Resi: ${_dummyResiData['resiNumber']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildResiDetailRow('Marketplace', _dummyResiData['marketplace']),
                      _buildResiDetailRow('Kurir', _dummyResiData['kurir']),
                      _buildResiDetailRow('Penerima', _dummyResiData['penerima']),
                      _buildResiDetailRow('No. HP', _dummyResiData['noHp']),
                      _buildResiDetailRow('Alamat', _dummyResiData['alamat']),
                      _buildResiDetailRow('Berat', _dummyResiData['berat']),
                      _buildResiDetailRow('Batas Kirim', _dummyResiData['batasKirim']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Card: Daftar Produk
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Daftar Produk (${_products.length} item)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...List.generate(_products.length, (index) {
                  return _buildProductCard(index);
                }),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Card: Status Resi
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siap kirim resi ${_dummyResiData['resiNumber']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_products.where((p) => p.isReady).length}/${_products.length} produk prepared',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _markResiReady,
                  icon: Icon(Icons.send),
                  label: Text('RESI SIAP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16), // Extra spacing at bottom to prevent overlap with system navigation bar
      ],
    );
  }

  Widget _buildResiDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final product = _products[index];
    final isCompleted = product.isReady;
    final isScanned = product.isScanned;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nama,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SKU: ${product.sku} | Qty: ${product.qty}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          if (isScanned) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  'Produk telah di-scan',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isScanned
                      ? null
                      : () => _startScanProduct(index),
                  icon: Icon(Icons.qr_code_scanner),
                  label: Text('SCAN PRODUK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isScanned ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isScanned && !isCompleted) ...[
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markProductReady(index),
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
          if (isCompleted) ...[
            SizedBox(height: 8),
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
    );
  }
}

// Model untuk Product
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
