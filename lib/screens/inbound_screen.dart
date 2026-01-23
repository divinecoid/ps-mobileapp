import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import '../models/barcode_product.dart' as bp;
import '../components/toast.dart';
import '../utils/beep_service.dart';
import '../api/inbound_service.dart';
import '../api/warehouse_service.dart';
import 'barcode_scanner_screen.dart';
import 'dart:convert';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  
  List<bp.BarcodeProduct> _scannedBarcodes = [];
  bool _isListExpanded = true;
  bool _isSubmitting = false;
  bool _isLoadingWarehouses = true;
  bool _warehouseLoadError = false;
  String? _selectedWarehouseId;
  final TextEditingController _notesController = TextEditingController();
  
  // Warehouse data from API
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    setState(() {
      _isLoadingWarehouses = true;
      _warehouseLoadError = false;
    });
    
    try {
      print('📦 Starting warehouse load...');
      final warehouses = await WarehouseService.getWarehouses();
      print('📦 Got ${warehouses.length} warehouses');
      
      if (mounted) {
        setState(() {
          _warehouses = warehouses;
          _isLoadingWarehouses = false;
          _warehouseLoadError = warehouses.isEmpty;
          // Set default warehouse to first one
          if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
            _selectedWarehouseId = _warehouses[0].id;
          }
        });
      }
    } catch (e) {
      print('❌ Error loading warehouses: $e');
      if (mounted) {
        setState(() {
          _isLoadingWarehouses = false;
          _warehouseLoadError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleMenuSelection(BuildContext context, String menu) {
    if (_scannedBarcodes.isNotEmpty) {
      _showExitConfirmation(
        context,
        () => NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'inbound'),
      );
    } else {
      NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'inbound');
    }
  }

  Future<bool> _onWillPop() async {
    if (_scannedBarcodes.isEmpty) {
      return true;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Peringatan'),
          ],
        ),
        content: Text(
          'Anda memiliki ${_scannedBarcodes.length} barcode yang belum di-submit.\n\nJika Anda keluar sekarang, semua data scan akan hilang.\n\nApakah Anda yakin ingin keluar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showExitConfirmation(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Peringatan'),
          ],
        ),
        content: Text(
          'Anda memiliki ${_scannedBarcodes.length} barcode yang belum di-submit.\n\nJika Anda pindah menu, semua data scan akan hilang.\n\nApakah Anda yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Pindah', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _handleBarcodeScanned(code);
        // Only process first barcode to avoid duplicates
        break;
      }
    }
  }

  void _handleBarcodeScanned(String barcode) {
    // Parse barcode dari format API:
    // CMT_CODE|REQUEST_DATE|MODEL_SKU|COLOR_CODE|SIZE_CODE|TYPE|SEQUENCE
    
    try {
      // Trim whitespace
      final cleanedBarcode = barcode.trim();
      
      // Debug: print barcode yang dibaca
      print('Barcode scanned: $barcode');
      
      // Cek apakah barcode sudah pernah discan
      if (_scannedBarcodes.any((b) => b.barcode == cleanedBarcode)) {
        // Play error beep untuk barcode yang sudah discan
        BeepService.playErrorBeep();
        Toast.show(context, '⚠️ Barcode sudah pernah di-scan');
        return;
      }

      // Parse barcode dengan separator pipe
      final parts = cleanedBarcode.split('|');
      
      print('Parsed parts: $parts (length: ${parts.length})');
      
      if (parts.length != 7) {
        // Play error beep untuk format tidak valid
        BeepService.playErrorBeep();
        Toast.show(context, '❌ Format barcode tidak valid');
        return;
      }

      final cmtCode = parts[0].trim();
      final requestDate = parts[1].trim();
      final modelSku = parts[2].trim();
      final colorCode = parts[3].trim();
      final sizeCode = parts[4].trim();
      final typeStr = parts[5].trim();
      final sequence = parts[6].trim();

      print('Parsed: cmt=$cmtCode, date=$requestDate, model=$modelSku, color=$colorCode, size=$sizeCode, type=$typeStr, seq=$sequence');

      final type = typeStr.toUpperCase() == 'DOZEN' 
          ? bp.BarcodeType.lusin 
          : bp.BarcodeType.satuan;
      
      final qty = type == bp.BarcodeType.lusin ? 12 : 1;

      // Untuk demo, gunakan nama yang lebih readable
      final modelName = _getModelName(modelSku);
      final colorName = _getColorName(colorCode);

      final barcodeProduct = bp.BarcodeProduct(
        barcode: cleanedBarcode, // Simpan barcode original
        type: type,
        model: modelName,
        warna: colorName,
        size: sizeCode,
        rak: cmtCode, // Sementara gunakan CMT code sebagai rak identifier
        qty: qty,
        requestId: 'REQ-$cmtCode-$requestDate',
      ).markAsScanned();

      setState(() {
        _scannedBarcodes.insert(0, barcodeProduct); // Insert at top
      });

      // Play success beep untuk barcode berhasil discan
      BeepService.playSuccessBeep();
      Toast.show(context, '✅ ${barcodeProduct.typeLabel} terscan');
    } catch (e) {
      print('Error parsing barcode: $e');
      // Play error beep untuk error
      BeepService.playErrorBeep();
      Toast.show(context, '❌ Error parsing barcode');
    }
  }

  String _getModelName(String code) {
    // Mapping kode ke nama model
    final modelMap = {
      'LC': 'LENGAN PANJANG KERAH',
      'LPK': 'LENGAN PANJANG KERAH',
      'LPS': 'LENGAN PENDEK',
      'TSH': 'T-SHIRT',
    };
    return modelMap[code.toUpperCase()] ?? code;
  }

  String _getColorName(String code) {
    // Mapping kode warna ke nama warna
    final colorMap = {
      'RED': 'Merah',
      'BLUE': 'Biru',
      'BLACK': 'Hitam',
      'WHITE': 'Putih',
      'GREEN': 'Hijau',
      'MERAH': 'Merah',
      'BIRU': 'Biru',
      'HITAM': 'Hitam',
      'PUTIH': 'Putih',
    };
    return colorMap[code.toUpperCase()] ?? code;
  }

  void _removeBarcode(bp.BarcodeProduct barcode) {
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
        content: Text('Apakah Anda yakin ingin menghapus semua barcode?'),
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

  Future<void> _submitInbound() async {
    if (_scannedBarcodes.isEmpty) {
      Toast.show(context, 'Belum ada barcode yang di-scan');
      return;
    }

    if (_selectedWarehouseId == null) {
      Toast.show(context, 'Pilih warehouse terlebih dahulu');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Extract raw barcodes
      final barcodes = _scannedBarcodes.map((b) => b.barcode).toList();

      // Call API
      final result = await InboundService.submitInbound(
        barcodes: barcodes,
        warehouseId: _selectedWarehouseId!,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success']) {
        _showSuccessDialog(result['data'], result['errors']);
      } else {
        _showErrorDialog(result['message'], result['errors']);
      }
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic>? data, List<dynamic>? errors) {
    print('📋 Errors received in dialog: $errors');
    final summary = data?['summary'];
    final hasErrors = errors != null && errors.isNotEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasErrors 
                  ? [Colors.orange.shade50, Colors.white]
                  : [Colors.green.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with circular background
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasErrors ? Colors.orange.shade100 : Colors.green.shade100,
                ),
                child: Icon(
                  hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: hasErrors ? Colors.orange.shade700 : Colors.green.shade700,
                  size: 40,
                ),
              ),
              
              SizedBox(height: 20),
              
              // Title
              Text(
                hasErrors ? 'Berhasil dengan Error' : 'Berhasil!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8),
              
              // Subtitle
              Text(
                hasErrors 
                    ? 'Beberapa item gagal diproses'
                    : 'Semua item berhasil diproses',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 24),
              
              // Summary cards
              if (summary != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Total Scanned',
                        '${summary['total_scanned']}',
                        Icons.qr_code_scanner,
                        Colors.blue,
                      ),
                      SizedBox(height: 12),
                      _buildSummaryRow(
                        'Processed',
                        '${summary['total_processed']}',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      if (summary['total_failed'] > 0) ...[
                        SizedBox(height: 12),
                        _buildSummaryRow(
                          'Failed',
                          '${summary['total_failed']}',
                          Icons.error_outline,
                          Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 24),
              
              // Copy Error Button (only show if there are errors)
              if (hasErrors && errors != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Format errors as JSON string
                      final errorText = JsonEncoder.withIndent('  ').convert(errors);
                      await Clipboard.setData(ClipboardData(text: errorText));
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Error details copied to clipboard'),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.copy, size: 18),
                    label: Text('Copy Error Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],
              
              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _scannedBarcodes.clear();
                      _notesController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasErrors ? Colors.orange.shade600 : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String message, dynamic errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  int get _totalItems {
    return _scannedBarcodes.fold(0, (sum, barcode) => sum + barcode.qty);
  }

  int get _totalLusin {
    return _scannedBarcodes.where((b) => b.type == bp.BarcodeType.lusin).length;
  }

  int get _totalSatuan {
    return _scannedBarcodes.where((b) => b.type == bp.BarcodeType.satuan).length;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _scannedBarcodes.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
              icon: Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _clearAllBarcodes,
              tooltip: 'Hapus Semua',
            ),
        ],
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(context, menu),
      ),
      body: Column(
        children: [
          // Scanner Section with Floating Summary
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                // QR Scanner
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                
                // Scanner Overlay
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                // Instruction Text
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black.withOpacity(0.6),
                    child: Text(
                      'Arahkan kamera ke QR Code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                // Floating Summary Card
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryChip(
                          'Total',
                          '${_scannedBarcodes.length}',
                          Icons.qr_code_scanner,
                          Colors.blue,
                        ),
                        _buildSummaryChip(
                          'Items',
                          '$_totalItems',
                          Icons.inventory_2,
                          Colors.green,
                        ),
                        _buildSummaryChip(
                          'Lusin',
                          '$_totalLusin',
                          Icons.layers,
                          Colors.orange,
                        ),
                        _buildSummaryChip(
                          'Satuan',
                          '$_totalSatuan',
                          Icons.style,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Scanned Items List Section
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  // List Header
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isListExpanded = !_isListExpanded;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Icon(
                            _isListExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Barcode Ter-scan (${_scannedBarcodes.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Scanned Items List
                  if (_isListExpanded)
                    Expanded(
                      child: _scannedBarcodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_outlined,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Scan QR code untuk mulai',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(8),
                              itemCount: _scannedBarcodes.length,
                              itemBuilder: (context, index) {
                                final barcode = _scannedBarcodes[index];
                                return _buildBarcodeCard(barcode);
                              },
                            ),
                    ),
                  
                  // Form Section
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warehouse Dropdown
                        Text(
                          'Warehouse',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        _isLoadingWarehouses
                            ? Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Memuat warehouse...'),
                                  ],
                                ),
                              )
                            : _warehouseLoadError || _warehouses.isEmpty
                                ? Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Gagal memuat warehouse',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _loadWarehouses,
                                          icon: Icon(Icons.refresh, size: 18),
                                          label: Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedWarehouseId,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      isDense: true,
                                    ),
                                    items: _warehouses.map((warehouse) {
                                      return DropdownMenuItem<String>(
                                        value: warehouse.id,
                                        child: Text(warehouse.displayName),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedWarehouseId = value;
                                      });
                                    },
                                  ),
                        
                        SizedBox(height: 16),
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitInbound,
                            icon: _isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Icon(Icons.send, size: 20),
                            label: Text(_isSubmitting ? 'Memproses...' : 'Submit Inbound'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        
                        // Bottom spacing for navigation bar
                        SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeCard(bp.BarcodeProduct barcode) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: barcode.type == bp.BarcodeType.lusin
                ? Colors.orange.shade100
                : Colors.purple.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            barcode.type == bp.BarcodeType.lusin ? Icons.layers : Icons.style,
            color: barcode.type == bp.BarcodeType.lusin
                ? Colors.orange.shade900
                : Colors.purple.shade900,
            size: 20,
          ),
        ),
        title: Text(
          barcode.displayName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Qty: ${barcode.qty} • ${barcode.typeLabel}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 20, color: Colors.red),
          onPressed: () => _removeBarcode(barcode),
        ),
      ),
    );
  }
}
