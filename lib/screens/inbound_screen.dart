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
import '../api/rack_service.dart';
import 'inbound_list_screen.dart';
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
  bool _isLoadingRacks = true;
  bool _rackLoadError = false;
  String? _selectedWarehouseId;
  final TextEditingController _notesController = TextEditingController();
  
  // Warehouse data from API
  List<Warehouse> _warehouses = [];
  
  // Rack data from API
  List<Rack> _racks = [];

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _loadRacks();
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

  Future<void> _loadRacks() async {
    setState(() {
      _isLoadingRacks = true;
      _rackLoadError = false;
    });
    
    try {
      print('🗄️ Starting rack load...');
      final racks = await RackService.getRacks();
      print('🗄️ Got ${racks.length} racks');
      
      if (mounted) {
        setState(() {
          _racks = racks;
          _isLoadingRacks = false;
          _rackLoadError = racks.isEmpty;
        });
      }
    } catch (e) {
      print('❌ Error loading racks: $e');
      if (mounted) {
        setState(() {
          _isLoadingRacks = false;
          _rackLoadError = true;
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
    // CMT_CODE|TIMESTAMP|MODEL_SKU|COLOR_CODE|SIZE_CODE|GROUP|SEQUENCE
    // Group kosong untuk piece, terisi untuk dozen
    
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
      final timestamp = parts[1].trim();
      final modelSku = parts[2].trim();
      final colorCode = parts[3].trim();
      final sizeCode = parts[4].trim();
      final group = parts[5].trim(); // Kosong untuk piece, terisi untuk dozen
      final sequence = parts[6].trim();

      print('Parsed: cmt=$cmtCode, timestamp=$timestamp, model=$modelSku, color=$colorCode, size=$sizeCode, group=$group, seq=$sequence');

      // Determine type based on GROUP field (empty = piece, filled = dozen)
      final isDozen = group.isNotEmpty;
      final type = isDozen ? bp.BarcodeType.lusin : bp.BarcodeType.satuan;
      final qty = isDozen ? 12 : 1;

      // Untuk demo, gunakan nama yang lebih readable
      final modelName = _getModelName(modelSku);
      final colorName = _getColorName(colorCode);

      if (isDozen) {
        // Dozen barcode - add directly without rack selection
        final barcodeProduct = bp.BarcodeProduct(
          barcode: cleanedBarcode,
          type: type,
          model: modelName,
          warna: colorName,
          size: sizeCode,
          rak: cmtCode,
          qty: qty,
          requestId: 'REQ-$cmtCode-$timestamp',
        ).markAsScanned();

        setState(() {
          _scannedBarcodes.insert(0, barcodeProduct);
        });

        BeepService.playSuccessBeep();
        Toast.show(context, '✅ ${barcodeProduct.typeLabel} terscan');
      } else {
        // Piece barcode - show rack selection dialog
        _showRackSelectionDialog(
          cleanedBarcode: cleanedBarcode,
          type: type,
          modelName: modelName,
          colorName: colorName,
          sizeCode: sizeCode,
          cmtCode: cmtCode,
          qty: qty,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      print('Error parsing barcode: $e');
      BeepService.playErrorBeep();
      Toast.show(context, '❌ Error parsing barcode');
    }
  }

  void _showRackSelectionDialog({
    required String cleanedBarcode,
    required bp.BarcodeType type,
    required String modelName,
    required String colorName,
    required String sizeCode,
    required String cmtCode,
    required int qty,
    required String timestamp,
  }) {
    String? selectedRackId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.style, color: Colors.purple.shade700, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Rak',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Barcode Piece',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$modelName - $colorName - $sizeCode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Qty: $qty pcs',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    'Pilih Rak Penyimpanan:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Rack dropdown
                  _isLoadingRacks
                      ? Container(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Memuat rak...'),
                            ],
                          ),
                        )
                      : _rackLoadError || _racks.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Gagal memuat rak',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await _loadRacks();
                                      setDialogState(() {});
                                    },
                                    child: Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: selectedRackId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                isDense: true,
                                hintText: 'Pilih rak...',
                              ),
                              items: _racks.map((rack) {
                                return DropdownMenuItem<String>(
                                  value: rack.id,
                                  child: Text(
                                    rack.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedRackId = value;
                                });
                              },
                            ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                BeepService.playErrorBeep();
                Toast.show(context, '❌ Barcode dibatalkan');
              },
              child: Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: selectedRackId == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      
                      // Add barcode with selected rack
                      final barcodeProduct = bp.BarcodeProduct(
                        barcode: cleanedBarcode,
                        type: type,
                        model: modelName,
                        warna: colorName,
                        size: sizeCode,
                        rak: cmtCode,
                        rackId: selectedRackId,
                        qty: qty,
                        requestId: 'REQ-$cmtCode-$timestamp',
                      ).markAsScanned();

                      setState(() {
                        _scannedBarcodes.insert(0, barcodeProduct);
                      });

                      BeepService.playSuccessBeep();
                      Toast.show(context, '✅ ${barcodeProduct.typeLabel} terscan');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Simpan'),
            ),
          ],
        ),
      ),
    );
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

    // Separate dozen and piece barcodes
    final dozenBarcodes = _scannedBarcodes
        .where((b) => b.type == bp.BarcodeType.lusin)
        .map((b) => b.barcode)
        .toList();
    
    final pieceBarcodes = _scannedBarcodes
        .where((b) => b.type == bp.BarcodeType.satuan)
        .map((b) => <String, String>{
          'barcode': b.barcode,
          'rack_id': b.rackId ?? '',
        })
        .toList();

    // Check if dozen barcodes exist but no warehouse selected
    if (dozenBarcodes.isNotEmpty && _selectedWarehouseId == null) {
      Toast.show(context, 'Pilih warehouse terlebih dahulu untuk penerimaan dozen');
      return;
    }

    // Check if piece barcodes exist but some don't have rack_id
    final piecesWithoutRack = pieceBarcodes.where((p) => p['rack_id']?.isEmpty ?? true).length;
    if (piecesWithoutRack > 0) {
      Toast.show(context, '$piecesWithoutRack barcode piece belum memiliki rak yang dipilih');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Call API with new format
      final result = await InboundService.submitInbound(
        barcodesDozens: dozenBarcodes.isNotEmpty ? dozenBarcodes : null,
        barcodesPieces: pieceBarcodes.isNotEmpty ? pieceBarcodes : null,
        warehouseId: dozenBarcodes.isNotEmpty ? _selectedWarehouseId : null,
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

  void _showSuccessDialog(Map<String, dynamic>? data, dynamic errors) {
    print('📋 Data received in dialog: $data');
    print('📋 Errors received in dialog: $errors');
    
    final totalScanned = data?['total_scanned'];
    final hasErrors = errors != null && (errors is List ? errors.isNotEmpty : (errors is Map && errors.isNotEmpty));

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
              
              // Summary cards - updated for new API format
              if (totalScanned != null) ...[
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
                        'Total Diproses',
                        '$totalScanned',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
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
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InboundListScreen(),
                ),
              );
            },
            tooltip: 'Daftar Penerimaan',
          ),
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
    // Get rack name if available for piece items
    String? rackName;
    if (barcode.type == bp.BarcodeType.satuan && barcode.rackId != null) {
      final rack = _racks.firstWhere(
        (r) => r.id == barcode.rackId,
        orElse: () => Rack(id: '', code: '', name: 'Unknown', warehouseId: ''),
      );
      if (rack.id.isNotEmpty) {
        rackName = rack.shortDisplayName;
      }
    }

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qty: ${barcode.qty} • ${barcode.typeLabel}',
              style: TextStyle(fontSize: 12),
            ),
            if (rackName != null) ...[
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 12, color: Colors.purple.shade600),
                  SizedBox(width: 4),
                  Text(
                    rackName,
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 20, color: Colors.red),
          onPressed: () => _removeBarcode(barcode),
        ),
      ),
    );
  }
}
