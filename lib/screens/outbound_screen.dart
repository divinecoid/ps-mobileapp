import 'package:flutter/material.dart';
import 'barcode_scanner_screen.dart';
import '../components/toast.dart';
import '../components/app_drawer.dart';
import '../models/product.dart';
import '../models/grouped_product_item.dart';
import '../api/outbound_service.dart';
import '../api/order_service.dart';
import '../utils/navigation_helper.dart';
import 'scan_product_group_screen.dart';
import 'outbound_list_screen.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  // State management
  String? _scannedResiNumber;
  bool _isLoading = false;
  List<Product> _products = [];
  Set<String> _scannedProductSkus = {};

  // Order data from API
  Map<String, dynamic>? _orderData;

  // Temporary prepared_at variable (set on AWB scan, cleared on cancel)
  String? _preparedAt;

  // Grouped products by SKU-Color-Size
  List<GroupedProductItem> _groupedProducts = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startScanResi() async {
    // Variable to hold the scanner's toast callback
    Function(String, {bool isError})? showScannerToast;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          title: 'Scan Resi',
          instruction: 'Arahkan kamera ke barcode resi marketplace',
          scanType: ScanType.barcode,
          onError: (showToast) {
            // Capture the callback from the scanner
            showScannerToast = showToast;
          },
          onScanResult: (barcode) async {
            // Validate AWB immediately when scanned, passing the toast callback
            await _validateAwb(barcode, showScannerToast);
            // Close scanner after successful scan
            if (mounted && _scannedResiNumber != null) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  Future<void> _validateAwb(
    String awbCode, [
    Function(String, {bool isError})? showScannerToast,
  ]) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await OutboundService.validateAwb(awbCode);

      if (!mounted) return;

      if (response['success'] == true) {
        final orderData = response['data']['order'];

        // Check if order is already prepared
        if (orderData['status'] != 'ready_to_pickup') {
          if (mounted) {
            if (showScannerToast != null) {
              showScannerToast(
                'Resi ini sudah disiapkan sebelumnya',
                isError: true,
              );
            } else {
              Toast.show(
                context,
                'Resi ini sudah disiapkan sebelumnya',
                isError: true,
              );
            }
          }
          return;
        }

        // Set temporary prepared_at variable in UTC
        final preparedAt = DateTime.now().toUtc().toIso8601String();

        setState(() {
          _orderData = orderData;
          _scannedResiNumber = orderData['awb_code'];
          _preparedAt = preparedAt; // Store temporary prepared_at in UTC
        });

        // Fetch order items
        await _fetchOrderItems(orderData['id']);

        if (mounted) {
          // Success message doesn't need to be blocking/top-priority toast if navigating away
          Toast.show(context, 'Resi berhasil di-scan');
        }
      } else {
        if (mounted) {
          if (showScannerToast != null) {
            showScannerToast(
              response['message'] ?? 'AWB tidak valid',
              isError: true,
            );
          } else {
            Toast.show(
              context,
              response['message'] ?? 'AWB tidak valid',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (showScannerToast != null) {
          showScannerToast('Error: Gagal memvalidasi AWB', isError: true);
        } else {
          Toast.show(context, 'Error: Gagal memvalidasi AWB', isError: true);
        }
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

        final List<Map<String, dynamic>> expandedItems = [];
        for (var item in items) {
          final id = (item['id'] ?? '').toString();
          final sku = (item['sku'] ?? '').toString().trim();
          final color = (item['color'] ?? '').toString().trim();
          final size = (item['size'] ?? '').toString().trim();
          final itemName = (item['item_name'] ?? '').toString().trim();
          final itemIndex = item['item_index'] ?? 1;

          final parsed = parseSku(sku, warnaString: color, ukuran: size);
          if (parsed.isEmpty) {
            expandedItems.add({
              'id': id,
              'sku': sku,
              'color': color,
              'size': size,
              'item_name': itemName,
              'item_index': itemIndex,
            });
          } else {
            for (var p in parsed) {
              final displayParts = [
                p.sku,
                if (p.logo != null) '(${p.logo})',
                p.warna,
                p.ukuran,
              ].where((s) => s != null && s!.isNotEmpty).toList();

              expandedItems.add({
                'id': id,
                'sku': p.sku,
                'color': p.warna ?? '',
                'size': p.ukuran ?? '',
                'item_name': displayParts.join(' '),
                'item_index': itemIndex,
              });
            }
          }
        }

        // Group items by SKU-Color-Size
        final Map<String, GroupedProductItem> groupedMap = {};

        for (var item in expandedItems) {
          final sku = item['sku'] as String;
          final color = item['color'] as String;
          final size = item['size'] as String;
          final id = item['id'] as String;

          // Create unique key for grouping
          final key = '$sku|$color|$size';

          // Create display name
          final displayName = [
            sku,
            color,
            size,
          ].where((s) => s.isNotEmpty).join(' - ');

          if (groupedMap.containsKey(key)) {
            // Increment quantity for existing group
            final existing = groupedMap[key]!;
            groupedMap[key] = existing.copyWith(
              requiredQuantity: existing.requiredQuantity + 1,
              orderItemIds: [...existing.orderItemIds, id],
            );
          } else {
            // Create new group
            groupedMap[key] = GroupedProductItem(
              sku: sku,
              color: color,
              size: size,
              displayName: displayName.isNotEmpty
                  ? displayName
                  : 'Unknown Item',
              requiredQuantity: 1,
              scannedBarcodes: [],
              orderItemIds: [id],
              isComplete: false,
            );
          }
        }

        setState(() {
          _groupedProducts = groupedMap.values.toList();
          _products = expandedItems
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
        Toast.show(context, 'Error: Gagal mengambil data item', isError: true);
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

  Future<void> _markResiReady() async {
    // Check if all groups are complete
    final allGroupsComplete = _groupedProducts.every((g) => g.isComplete);
    if (!allGroupsComplete) {
      Toast.show(
        context,
        'Semua grup produk harus selesai di-scan terlebih dahulu',
        isError: true,
      );
      return;
    }

    // Collect scanned barcodes mapping to order item IDs
    // Since item order matters for mapping, we assign 1 scanned barcode to 1 orderItemId
    final List<Map<String, dynamic>> orderItemsPayload = [];
    for (var group in _groupedProducts) {
      // In theory group.scannedBarcodes.length == group.orderItemIds.length if isComplete
      for (int i = 0; i < group.scannedBarcodes.length; i++) {
        if (i < group.orderItemIds.length) {
          orderItemsPayload.add({
            'id': group.orderItemIds[i],
            'scanned_barcodes': [group.scannedBarcodes[i]]
          });
        }
      }
    }

    if (_orderData == null || _preparedAt == null) {
      Toast.show(context, 'Data order tidak lengkap', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Submit preparation to backend
      final response = await OrderService.submitPreparation(
        orderId: _orderData!['id'],
        preparedAt: _preparedAt!,
        orderItems: orderItemsPayload,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccessDialog();
      } else {
        Toast.show(
          context,
          response['message'] ?? 'Gagal submit preparation',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Error: Gagal submit preparation', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                  _orderData = null;
                  _preparedAt = null; // Clear temporary prepared_at
                  _groupedProducts = [];
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

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Batalkan Order?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan proses persiapan order ini?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua data scan akan hilang',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tidak',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset state
              setState(() {
                _scannedResiNumber = null;
                _products = [];
                _scannedProductSkus = {};
                _orderData = null;
                _preparedAt = null; // Clear temporary prepared_at
                _groupedProducts = [];
              });
              Toast.show(context, 'Order dibatalkan');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Ya, Batalkan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OutboundListScreen(),
                ),
              );
            },
            tooltip: 'History Outbound',
          ),
        ],
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
        // Card: Daftar Produk (Grouped by Variant)
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
                      'Daftar Produk (${_groupedProducts.length} variant)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...List.generate(_groupedProducts.length, (index) {
                  return _buildGroupedProductCard(index);
                }),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Tombol RESI SIAP dan BATALKAN
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _markResiReady,
                icon: Icon(Icons.check_circle),
                label: Text('RESI SIAP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _showCancelConfirmation,
                icon: Icon(Icons.cancel, size: 20),
                label: Text('BATAL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red, width: 2),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildGroupedProductCard(int index) {
    final group = _groupedProducts[index];

    return GestureDetector(
      onTap: () async {
        // Navigate to scan screen for editing
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanProductGroupScreen(
              productGroup: group,
              onGroupComplete: (completedGroup) {
                setState(() {
                  _groupedProducts[index] = completedGroup;
                });
              },
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: group.isComplete ? Colors.green : Colors.grey.shade300,
            width: group.isComplete ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: group.isComplete
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      group.isComplete ? Icons.check_circle : Icons.inventory_2,
                      color: group.isComplete ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Qty: ${group.scannedCount} / ${group.requiredQuantity}',
                        style: TextStyle(
                          fontSize: 14,
                          color: group.isComplete
                              ? Colors.green
                              : Colors.grey[700],
                          fontWeight: group.isComplete
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanProductGroupScreen(
                          productGroup: group,
                          onGroupComplete: (completedGroup) {
                            setState(() {
                              _groupedProducts[index] = completedGroup;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    group.isComplete ? Icons.edit : Icons.qr_code_scanner,
                    size: 18,
                  ),
                  label: Text(
                    group.isComplete ? 'EDIT' : 'SCAN',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: group.isComplete
                        ? Colors.orange
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}

class ParsedSkuItem {
  final String sku;
  final String? logo;
  final String? warna;
  final String? ukuran;

  ParsedSkuItem({
    required this.sku,
    this.logo,
    this.warna,
    this.ukuran,
  });
}

List<ParsedSkuItem> parseSku(String skuText, {String warnaString = '', String? ukuran}) {
  final regex = RegExp(r'^(?:(PAKET(\d+))-)?(?:(.+?)\*)?([^+]+)(?:\+(.+))?$');
  final match = regex.firstMatch(skuText);

  if (match == null) return [];

  final jumlahStr = match.group(2);
  final jumlah = jumlahStr != null ? int.tryParse(jumlahStr) ?? 1 : 1;
  final logo = match.group(3);
  final skuUtama = match.group(4) ?? '';
  final extra = match.group(5);

  final RegExp colorSplitRegExp = RegExp(r'[|=]');
  final List<String> warnaList = warnaString.isNotEmpty ? warnaString.split(colorSplitRegExp) : [];
  final List<ParsedSkuItem> result = [];

  for (int i = 0; i < jumlah; i++) {
    String warna = 'Hitam';
    if (i < warnaList.length && warnaList[i].trim().isNotEmpty) {
      warna = warnaList[i].trim();
    }
    result.add(ParsedSkuItem(
      sku: skuUtama.trim(),
      logo: logo?.trim(),
      warna: warna,
      ukuran: ukuran,
    ));
  }

  if (extra != null && extra.trim().isNotEmpty) {
    result.add(ParsedSkuItem(
      sku: extra.trim(),
      logo: null,
      warna: 'Hitam',
      ukuran: ukuran,
    ));
  }

  return result;
}
