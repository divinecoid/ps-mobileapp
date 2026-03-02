import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import '../models/barcode_product.dart' as bp;
import '../components/toast.dart';
import '../utils/sound_service.dart';
import '../api/inbound_service.dart';
import '../api/warehouse_service.dart';
import '../api/rack_service.dart';
import 'dart:async';
import 'inbound_list_screen.dart';
import 'barcode_scanner_screen.dart';
import 'dart:convert';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  
  bool _isProcessingScan = false;
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

  // Set to prevent duplicate API calls for same barcode while validating
  final Set<String> _validatingBarcodes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    _tabController.dispose();
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
    if (_isProcessingScan) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        // Cek apakah scan yang sama sedang dalam proses validasi
        if (_validatingBarcodes.contains(code.trim())) {
          return;
        }

        setState(() {
          _isProcessingScan = true;
        });

        // Use isReject based on active tab
        final isReject = _tabController.index == 1;

        _handleBarcodeScanned(code, isReject: isReject).then((_) {
          // Beri jeda 1 detik setelah proses selesai (atau setelah dialog ditutup)
          // agar tidak langsung spam scan barang berikutnya
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _isProcessingScan = false;
              });
            }
          });
        });
        
        // Only process first barcode frame to avoid duplicate racing
        break;
      }
    }
  }

  Future<void> _handleBarcodeScanned(String barcode, {required bool isReject}) async {
    try {
      // Trim whitespace
      final cleanedBarcode = barcode.trim();
      
      // Prevent rapid scanning of same barcode while still validating
      // (Sudah ditangani di atas _onDetect, namun tetap dijaga di sini)
      if (_validatingBarcodes.contains(cleanedBarcode)) {
        return;
      }
      
      // Debug: print barcode yang dibaca
      print('Barcode scanned: $barcode (Reject: $isReject)');
      
      // Cek apakah barcode sudah pernah discan secara lokal
      if (_scannedBarcodes.any((b) => b.barcode == cleanedBarcode)) {
        // Play error beep untuk barcode yang sudah discan
        await SoundService().playError();
        Toast.show(context, '⚠️ Barcode sudah ada di list scan');
        return;
      }

      // Parse barcode dengan separator pipe just for basic format check before API call
      final parts = cleanedBarcode.split('|');
      
      if (parts.length != 7) {
        // Play error beep untuk format tidak valid
        await SoundService().playError();
        Toast.show(context, '❌ Format barcode tidak valid');
        return;
      }

      setState(() {
        _validatingBarcodes.add(cleanedBarcode);
      });

      // Show validating indicator if needed, but Toast might be enough or just silent until result
      print('Validating barcode via API: $cleanedBarcode');
      final result = await InboundService.validateBarcode(cleanedBarcode);
      
      if (!mounted) return;

      if (!result['success']) {
        await SoundService().playError();
        Toast.show(context, '❌ ${result['message']}');
        return;
      }

      final data = result['data'];
      
      final cmtCode = data['cmt']['code'];
      final cmtName = data['cmt']['name'];
      final modelName = data['model']['name'];
      final colorName = data['color']['name'];
      final sizeCode = data['size']['code'];
      
      // Pembeda piece dan dozen sekarang di index 5: D (dozen), P (piece)
      // Tetap gunakan API response sebagai prioritas, tapi fallback ke parsing string jika perlu
      final String barcodeTypeChar = parts[5].trim().toUpperCase();
      final bool isDozen = data['is_dozen'] == true || barcodeTypeChar == 'D';
      
      final timestamp = parts[1].trim(); // Extract timestamp for local object construction if needed

      final type = isDozen ? bp.BarcodeType.lusin : bp.BarcodeType.satuan;
      final qty = isDozen ? 12 : 1;

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
          isReject: isReject,
        ).markAsScanned();

        setState(() {
          _scannedBarcodes.insert(0, barcodeProduct);
        });

        await SoundService().playSuccess();
        Toast.show(context, '✅ ${barcodeProduct.typeLabel} ${isReject ? 'BS ' : ''}terscan\n$modelName - $colorName');
      } else {
        // Piece barcode - show rack selection dialog
        // 1. Play success alert indicating barcode is recognized
        await SoundService().playSuccess();
        
        // 2. Stop main scanner before showing dialog so it doesn't scan barcodes behind the dialog
        await _scannerController.stop();
        
        await _showRackSelectionDialog(
          cleanedBarcode: cleanedBarcode,
          type: type,
          modelName: modelName,
          colorName: colorName,
          sizeCode: sizeCode,
          cmtCode: cmtCode,
          qty: qty,
          timestamp: timestamp,
          isReject: isReject,
        );
        
        // Start scanner again after dialog is closed
        if (mounted) {
          await _scannerController.start();
        }
      }
    } catch (e) {
      print('Error parsing barcode: $e');
      await SoundService().playError();
      if (mounted) Toast.show(context, '❌ Error parsing barcode');
    } finally {
      if (mounted) {
        setState(() {
          _validatingBarcodes.remove(barcode.trim());
        });
      }
    }
  }

  Future<void> _showRackSelectionDialog({
    required String cleanedBarcode,
    required bp.BarcodeType type,
    required String modelName,
    required String colorName,
    required String sizeCode,
    required String cmtCode,
    required int qty,
    required String timestamp,
    required bool isReject,
  }) async {
    final TextEditingController rackCodeController = TextEditingController();
    Timer? _debounce;
    bool _isValidating = false;
    String? _validatedRackId;
    String? _validatedRackName;
    String? _rackError;

    // Helper function to validate rack from API
    Future<void> _validateRack(String code, StateSetter setDialogState) async {
      if (code.isEmpty) {
        setDialogState(() {
          _validatedRackId = null;
          _validatedRackName = null;
          _rackError = null;
          _isValidating = false;
        });
        return;
      }

      setDialogState(() {
        _isValidating = true;
        _validatedRackId = null;
        _validatedRackName = null;
        _rackError = null;
      });

      final rack = await RackService.getRackByCode(code);

      if (rack != null) {
        setDialogState(() {
          _validatedRackId = rack.id;
          _validatedRackName = rack.name;
          _isValidating = false;
          _rackError = null;
        });
      } else {
        setDialogState(() {
          _isValidating = false;
          _rackError = 'Rak tidak ditemukan';
        });
      }
    }

    await showDialog(
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
                  
                  // Rack Text Input with QR Scan
                  TextFormField(
                    controller: rackCodeController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                      hintText: 'Ketik atau scan kode rak...',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.qr_code_scanner, color: Colors.blue.shade700),
                        onPressed: () async {
                          // Hentikan sementara scanner utama agar kamera bisa digunakan di screen baru
                          await _scannerController.stop();

                          final scannedCode = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BarcodeScannerScreen(
                                title: 'Scan QR Rak',
                                instruction: 'Arahkan kamera ke QR Code Rak',
                                scanType: ScanType.qrCode,
                                onScanResult: (code) {
                                  Navigator.pop(context, code);
                                },
                              ),
                            ),
                          );
                          
                          // Tunggu sebentar agar BarcodeScannerScreen benar-benar ke-dispose 
                          // dan melepas resource hardware kamera (mengakali layar hitam/blank)
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // Jalankan kembali scanner utama
                          if (mounted) {
                            await _scannerController.start();
                          }
                          
                          if (scannedCode != null && scannedCode.isNotEmpty) {
                            setDialogState(() {
                              rackCodeController.text = scannedCode;
                            });
                            // Validasi otomatis saat dari scanner
                            await _validateRack(scannedCode, setDialogState);
                          }
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {}); // Rebuild instantly for text update
                      
                      // Debounce api call
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 700), () {
                        _validateRack(value.trim(), setDialogState);
                      });
                    },
                  ),
                  
                  // Validation status mapping
                  if (_isValidating)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Memeriksa kode rak...', style: TextStyle(fontSize: 12, color: Colors.blue)),
                        ],
                      ),
                    )
                  else if (_rackError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text(_rackError!, style: TextStyle(fontSize: 12, color: Colors.red)),
                        ],
                      ),
                    )
                  else if (_validatedRackName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$_validatedRackName', 
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SoundService().playError();
                Toast.show(context, '❌ Barcode dibatalkan');
              },
              child: Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: (!isReject && (_validatedRackId == null || _isValidating)) || (isReject && _isValidating)
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
                        rackId: _validatedRackId,
                        rackCode: rackCodeController.text.trim(),
                        qty: qty,
                        requestId: 'REQ-$cmtCode-$timestamp',
                        isReject: isReject,
                      ).markAsScanned();

                      setState(() {
                        _scannedBarcodes.insert(0, barcodeProduct);
                      });

                      SoundService().playSuccess();
                      Toast.show(context, '✅ ${barcodeProduct.typeLabel} ${isReject ? 'BS ' : ''}terscan');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isReject ? Colors.red.shade600 : Colors.purple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isReject && _validatedRackId == null ? 'Simpan (Tanpa Rak)' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
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
        .map((b) => {
          'barcode': b.barcode,
          'is_reject': b.isReject,
        })
        .toList();
    
    final pieceBarcodes = _scannedBarcodes
        .where((b) => b.type == bp.BarcodeType.satuan)
        .map((b) => {
          'barcode': b.barcode,
          'rack_id': b.rackId ?? '',
          'is_reject': b.isReject,
        })
        .toList();

    // Check if dozen barcodes exist but no warehouse selected
    if (dozenBarcodes.any((b) => b['is_reject'] == false) && _selectedWarehouseId == null) {
      Toast.show(context, 'Pilih warehouse terlebih dahulu untuk penerimaan dozen');
      return;
    }

    // Check if piece barcodes exist but some don't have rack_id (only for non-reject items)
    final piecesWithoutRack = pieceBarcodes.where((p) {
      final isReject = p['is_reject'] as bool? ?? false;
      final rackId = p['rack_id'] as String? ?? '';
      return !isReject && rackId.isEmpty;
    }).length;
    if (piecesWithoutRack > 0) {
      Toast.show(context, '$piecesWithoutRack barcode piece belum divalidasi dengan id rak yang valid');
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
        warehouseId: dozenBarcodes.any((b) => b['is_reject'] == false) ? _selectedWarehouseId : null,
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

  int get _totalBarcodes {
    return _scannedBarcodes.length;
  }

  int get _totalItems {
    return _scannedBarcodes.fold(0, (sum, barcode) => sum + barcode.qty);
  }

  int get _totalAcceptedLusin {
    return _scannedBarcodes
        .where((b) => !b.isReject && b.type == bp.BarcodeType.lusin)
        .length;
  }

  int get _totalAcceptedSatuan {
    return _scannedBarcodes
        .where((b) => !b.isReject && b.type == bp.BarcodeType.satuan)
        .length;
  }

  int get _totalRejectQty {
    return _scannedBarcodes
        .where((b) => b.isReject)
        .fold(0, (sum, barcode) => sum + barcode.qty);
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
        resizeToAvoidBottomInset: false,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade200,
          tabs: [
            Tab(
              icon: Icon(Icons.check_circle_outline),
              text: 'BISA DITERIMA',
            ),
            Tab(
              icon: Icon(Icons.report_problem_outlined),
              text: 'REJECT (BS)',
            ),
          ],
        ),
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(context, menu),
      ),
      backgroundColor: _tabController.index == 1 
          ? Colors.red.shade50 
          : Colors.green.shade50,
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
                          '$_totalBarcodes',
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
                          '$_totalAcceptedLusin',
                          Icons.layers,
                          Colors.orange,
                        ),
                        _buildSummaryChip(
                          'Satuan',
                          '$_totalAcceptedSatuan',
                          Icons.style,
                          Colors.purple,
                        ),
                        _buildSummaryChip(
                          'Reject',
                          '$_totalRejectQty',
                          Icons.report_problem,
                          Colors.red,
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
              // The outer container already has background from Scaffold, 
              // but we might want a slightly distinct color for the list area if needed.
              // For now, let's keep it transparent to show the Scaffold background.
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
                    // Semi-transparent white to show some background color
                    color: Colors.white.withOpacity(0.9),
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
    if (barcode.type == bp.BarcodeType.satuan && barcode.rackCode != null) {
      rackName = barcode.rackCode;
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
            color: barcode.isReject 
                ? Colors.red.shade900
                : (barcode.type == bp.BarcodeType.lusin
                    ? Colors.orange.shade900
                    : Colors.purple.shade900),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                barcode.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (barcode.isReject)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  'BS',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
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
