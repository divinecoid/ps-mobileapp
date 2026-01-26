import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import '../components/loading.dart';
import '../components/toast.dart';
import '../components/app_drawer.dart';
import '../models/product.dart';
import 'prepare_items_screen.dart';
import '../utils/navigation_helper.dart';
import '../api/outbound_service.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  // State management
  String? _scannedResiNumber;
  bool _isLoading = false;
  bool _isOrderTaken = false; // Track apakah order sudah diambil
  List<Product> _products = [];
  Set<String> _scannedProductSkus = {};

  // Order data from API
  Map<String, dynamic>? _orderData;

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
          },
        ),
      ),
    );

    // Validate AWB with backend API
    if (result != null && result.isNotEmpty && mounted) {
      await _validateAwb(result);
    }
  }

  Future<void> _validateAwb(String awbCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await OutboundService.validateAwb(awbCode);

      if (!mounted) return;

      if (response['success'] == true) {
        final orderData = response['data']['order'];

        setState(() {
          _orderData = orderData;
          _scannedResiNumber = orderData['awb_code'];
          _isOrderTaken = false;
        });

        // Fetch order items
        await _fetchOrderItems(orderData['id']);

        if (mounted) {
          Toast.show(context, 'Resi berhasil di-scan');
        }
      } else {
        if (mounted) {
          Toast.show(context, response['message'] ?? 'AWB tidak valid');
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Error: Gagal memvalidasi AWB');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchOrderItems(String orderId) async {
    try {
      final response = await OutboundService.getOrderItems(orderId);

      if (!mounted) return;

      if (response['success'] == true) {
        final items = response['data']['items'] as List;

        setState(() {
          _products = items
              .map(
                (item) => Product(
                  sku: item['sku'] ?? '',
                  nama: item['item_name'] ?? '',
                  qty: item['item_index'] ?? 1,
                  lokasi: {
                    'lantai': '1',
                    'ruang': 'A',
                    'rak': '001',
                    'bin': '01',
                  },
                  isScanned: false,
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Error: Gagal mengambil data item');
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

  void _takeOrder() {
    setState(() {
      _isOrderTaken = true;
    });
    if (mounted) {
      Toast.show(context, 'Order berhasil diambil');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  _isOrderTaken = false;
                  _orderData = null;
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
    NavigationHelper.handleMenuSelection(
      context,
      menu,
      currentScreen: 'outbound',
    );
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(onMenuSelected: _handleMenuSelection),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
    if (_orderData == null) return SizedBox.shrink();

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
                    Expanded(
                      child: Text(
                        'Data Resi: ${_orderData!['awb_code'] ?? ''}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      _buildResiDetailRow(
                        'Order SN',
                        _orderData!['order_sn'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'Marketplace',
                        _orderData!['marketplace']?['name'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'Online Store',
                        _orderData!['online_store']?['name'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'Penerima',
                        _orderData!['customer_name'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'No. HP',
                        _orderData!['customer_phone'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'Alamat',
                        _orderData!['customer_address'] ?? '-',
                      ),
                      _buildResiDetailRow(
                        'Berat',
                        '${_orderData!['total_weight'] ?? 0} gr',
                      ),
                      _buildResiDetailRow(
                        'Total Item',
                        '${_orderData!['item_count'] ?? 0}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Card: Status
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Text(
                'Status: ${_orderData!['status'] ?? '-'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
            ],
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
        // Tombol Ambil Order (muncul pertama kali setelah scan)
        if (!_isOrderTaken) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takeOrder,
              icon: Icon(Icons.shopping_cart),
              label: Text('AMBIL ORDER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        // Tombol Siapkan Barang dan Card Status Resi (muncul setelah ambil order)
        if (_isOrderTaken) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrepareItemsScreen(
                      products: _products,
                      onProductScanned: (index, product) {
                        setState(() {
                          _products[index] = product;
                        });
                      },
                      onProductReady: (index) {
                        setState(() {
                          _products[index] = Product(
                            sku: _products[index].sku,
                            nama: _products[index].nama,
                            qty: _products[index].qty,
                            lokasi: _products[index].lokasi,
                            isScanned: _products[index].isScanned,
                            isReady: true,
                          );
                        });
                      },
                    ),
                  ),
                );
              },
              icon: Icon(Icons.inventory_2),
              label: Text('Siapkan Barang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                          'Siap kirim resi ${_orderData?['awb_code'] ?? ''}',
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
        ],
        SizedBox(
          height: 16,
        ), // Extra spacing at bottom to prevent overlap with system navigation bar
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
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(int index) {
    final product = _products[index];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
                  color: Colors.grey,
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
