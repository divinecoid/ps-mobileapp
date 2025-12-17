import 'package:flutter/material.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import '../models/barcode_product.dart';
import 'barcode_scanner_screen.dart';
import '../components/toast.dart';
import 'inbound_summary_screen.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  List<BarcodeProduct> _scannedBarcodes = [];
  bool _isLoading = false;

  void _handleMenuSelection(BuildContext context, String menu) {
    NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'inbound');
  }

  Future<void> _startScanBarcode() async {
    // Langsung buka QR scanner untuk mobile-friendly
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          title: 'Scan QR Code',
          instruction: 'Arahkan kamera ke QR code barcode lusin atau satuan',
          scanType: ScanType.qrCode, // Gunakan QR code untuk mobile-friendly
          onScanResult: (barcode) {
            // Callback dipanggil saat QR code terdeteksi
          },
        ),
      ),
    );

    if (result != null && mounted) {
      _handleBarcodeScanned(result);
    }
  }


  void _addDummyBarcode() {
    // Generate dummy barcode untuk testing
    final dummyBarcodes = [
      'LPK-MERAH-S-RAK01-001-LUSIN',
      'LPK-MERAH-S-RAK01-002-LUSIN',
      'LPK-MERAH-S-RAK01-001-PCS',
      'LPK-MERAH-M-RAK01-001-PCS',
      'LPK-MERAH-L-RAK01-001-LUSIN',
      'LPK-MERAH-L-RAK01-001-PCS',
      'LPK-BIRU-S-RAK02-001-LUSIN',
      'LPK-BIRU-M-RAK02-001-PCS',
    ];

    // Ambil barcode yang belum pernah discan
    final availableBarcodes = dummyBarcodes
        .where((barcode) => !_scannedBarcodes.any((b) => b.barcode == barcode))
        .toList();

    if (availableBarcodes.isEmpty) {
      Toast.show(context, 'Semua dummy barcode sudah di-scan');
      return;
    }

    // Random atau ambil yang pertama
    final barcode = availableBarcodes[0];
    _handleBarcodeScanned(barcode);
  }

  void _handleBarcodeScanned(String barcode) {
    // Simulasi: Parse barcode dan buat BarcodeProduct
    // Dalam implementasi nyata, barcode akan digunakan untuk fetch data dari API
    // atau parse dari format barcode yang sudah ditentukan
    
    // Contoh parsing barcode: LPK-MERAH-S-RAK01-001-LUSIN
    // atau: LPK-MERAH-S-RAK01-001-PCS
    
    try {
      // Trim whitespace dan normalize
      final cleanedBarcode = barcode.trim().toUpperCase();
      
      // Debug: print barcode yang dibaca
      print('Barcode scanned: $barcode');
      print('Cleaned barcode: $cleanedBarcode');
      
      // Cek apakah barcode sudah pernah discan (cek dengan cleaned version juga)
      if (_scannedBarcodes.any((b) => b.barcode == barcode || b.barcode.toUpperCase() == cleanedBarcode)) {
        Toast.show(context, 'Barcode sudah pernah di-scan');
        return;
      }

      // Parse barcode (contoh format: LPK-MERAH-S-RAK01-001-LUSIN)
      // Handle berbagai format separator
      final parts = cleanedBarcode.split(RegExp(r'[-_\s]+')).where((p) => p.isNotEmpty).toList();
      
      print('Parsed parts: $parts (length: ${parts.length})');
      
      if (parts.length < 6) {
        // Coba format alternatif jika kurang dari 6 bagian
        // Mungkin formatnya berbeda atau ada whitespace
        Toast.show(context, 'Format barcode tidak valid. Ditemukan: ${parts.length} bagian. Barcode: $cleanedBarcode');
        return;
      }

      final model = parts[0].trim(); // LPK
      final warna = parts[1].trim(); // MERAH
      final size = parts[2].trim(); // S atau L
      final rak = parts[3].trim(); // RAK01
      final sequence = parts[4].trim(); // 001
      final typeStr = parts[5].trim(); // LUSIN atau PCS

      print('Parsed: model=$model, warna=$warna, size=$size, rak=$rak, sequence=$sequence, type=$typeStr');

      final type = typeStr.contains('LUSIN') 
          ? BarcodeType.lusin 
          : BarcodeType.satuan;
      
      final qty = type == BarcodeType.lusin ? 12 : 1;

      // Untuk demo, gunakan nama model yang lebih readable
      final modelName = _getModelName(model);
      final warnaName = _getWarnaName(warna);

      final barcodeProduct = BarcodeProduct(
        barcode: cleanedBarcode, // Simpan dalam format cleaned
        type: type,
        model: modelName,
        warna: warnaName,
        size: size,
        rak: rak,
        qty: qty,
        requestId: 'REQ-2024-001',
      ).markAsScanned();

      setState(() {
        _scannedBarcodes.add(barcodeProduct);
      });

      Toast.show(context, 'Barcode berhasil di-scan: ${barcodeProduct.typeLabel}');
    } catch (e) {
      print('Error parsing barcode: $e');
      Toast.show(context, 'Error parsing barcode: $e');
    }
  }

  String _getModelName(String code) {
    // Mapping kode ke nama model
    final modelMap = {
      'LPK': 'LENGAN PANJANG KERAH',
      'LPS': 'LENGAN PENDEK',
      'TSH': 'T-SHIRT',
    };
    return modelMap[code] ?? code;
  }

  String _getWarnaName(String code) {
    // Mapping kode warna ke nama warna
    final warnaMap = {
      'MERAH': 'Merah',
      'BIRU': 'Biru',
      'HITAM': 'Hitam',
      'PUTIH': 'Putih',
    };
    return warnaMap[code] ?? code;
  }

  void _removeBarcode(BarcodeProduct barcode) {
    setState(() {
      _scannedBarcodes.remove(barcode);
    });
    Toast.show(context, 'Barcode dihapus');
  }

  void _clearAllBarcodes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Semua'),
        content: Text('Apakah Anda yakin ingin menghapus semua barcode yang sudah di-scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _scannedBarcodes.clear();
              });
              Navigator.pop(context);
              Toast.show(context, 'Semua barcode dihapus');
            },
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToSummary() {
    if (_scannedBarcodes.isEmpty) {
      Toast.show(context, 'Belum ada barcode yang di-scan');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InboundSummaryScreen(
          scannedBarcodes: _scannedBarcodes,
        ),
      ),
    );
  }

  int get _totalItems {
    return _scannedBarcodes.fold(0, (sum, barcode) => sum + barcode.qty);
  }

  int get _totalLusin {
    return _scannedBarcodes.where((b) => b.type == BarcodeType.lusin).length;
  }

  int get _totalSatuan {
    return _scannedBarcodes.where((b) => b.type == BarcodeType.satuan).length;
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
          'INBOUND',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_scannedBarcodes.isNotEmpty)
            IconButton(
              icon: Icon(Icons.summarize, color: Colors.white),
              onPressed: _navigateToSummary,
              tooltip: 'Summary',
            ),
        ],
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(context, menu),
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Barcode',
                        '${_scannedBarcodes.length}',
                        Icons.qr_code_scanner,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Item',
                        '$_totalItems',
                        Icons.inventory_2,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Lusin',
                        '$_totalLusin',
                        Icons.layers,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryItem(
                        'Satuan',
                        '$_totalSatuan',
                        Icons.style,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scan QR Code Button & Add Dummy Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startScanBarcode,
                    icon: Icon(Icons.qr_code_scanner, size: 24),
                    label: Text('Scan QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addDummyBarcode,
                  icon: Icon(Icons.add_circle_outline, size: 20),
                  label: Text('Dummy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // List Scanned Barcodes
          Expanded(
            child: _scannedBarcodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada barcode yang di-scan',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tekan tombol "Scan Barcode" untuk mulai',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Header dengan clear button
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Barcode Ter-scan (${_scannedBarcodes.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _clearAllBarcodes,
                              icon: Icon(Icons.delete_outline, size: 18),
                              label: Text('Hapus Semua'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _scannedBarcodes.length,
                          itemBuilder: (context, index) {
                            final barcode = _scannedBarcodes[index];
                            return _buildBarcodeCard(barcode);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeCard(BarcodeProduct barcode) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show detail dialog
          _showBarcodeDetail(barcode);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Type Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: barcode.type == BarcodeType.lusin
                          ? Colors.orange.shade100
                          : Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: barcode.type == BarcodeType.lusin
                            ? Colors.orange
                            : Colors.purple,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          barcode.type == BarcodeType.lusin
                              ? Icons.layers
                              : Icons.style,
                          size: 14,
                          color: barcode.type == BarcodeType.lusin
                              ? Colors.orange.shade900
                              : Colors.purple.shade900,
                        ),
                        SizedBox(width: 4),
                        Text(
                          barcode.typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: barcode.type == BarcodeType.lusin
                                ? Colors.orange.shade900
                                : Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  // Remove button
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () => _removeBarcode(barcode),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                barcode.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warehouse, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    'Rak: ${barcode.rak}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.inventory_2, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    'Qty: ${barcode.qty}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.qr_code, size: 14, color: Colors.grey.shade500),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      barcode.barcode,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (barcode.scannedAt != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    SizedBox(width: 4),
                    Text(
                      'Scanned: ${_formatDateTime(barcode.scannedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBarcodeDetail(BarcodeProduct barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Barcode'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Barcode', barcode.barcode),
              _buildDetailRow('Tipe', barcode.typeLabel),
              _buildDetailRow('Model', barcode.model),
              _buildDetailRow('Warna', barcode.warna),
              _buildDetailRow('Size', barcode.size),
              _buildDetailRow('Rak', barcode.rak),
              _buildDetailRow('Qty', '${barcode.qty}'),
              if (barcode.requestId != null)
                _buildDetailRow('Request ID', barcode.requestId!),
              if (barcode.scannedAt != null)
                _buildDetailRow('Waktu Scan', _formatDateTime(barcode.scannedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade900),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
