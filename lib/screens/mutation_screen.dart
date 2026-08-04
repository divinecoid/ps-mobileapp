import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import '../models/barcode_product.dart' as bp;
import '../components/toast.dart';
import '../utils/sound_service.dart';
import '../api/mutation_service.dart';
import '../api/rack_service.dart';
import 'mutation_list_screen.dart';
import 'dart:convert';

class MutationScreen extends StatefulWidget {
  const MutationScreen({super.key});

  @override
  State<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends State<MutationScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  
  List<bp.BarcodeProduct> _scannedBarcodes = [];
  bool _isListExpanded = true;
  bool _isSubmitting = false;
  bool _isLoadingRacks = true;
  bool _rackLoadError = false;
  final TextEditingController _notesController = TextEditingController();
  
  // Rack data from API
  List<Rack> _racks = [];
  Rack? _activeRack;

  @override
  void initState() {
    super.initState();
    _loadRacks();
  }

  Future<void> _loadRacks() async {
    setState(() {
      _isLoadingRacks = true;
      _rackLoadError = false;
    });
    
    try {
      final racks = await RackService.getRacks();
      if (mounted) {
        setState(() {
          _racks = racks;
          _isLoadingRacks = false;
          _rackLoadError = racks.isEmpty;
        });
      }
    } catch (e) {
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
      _scannerController.stop();
      _showExitConfirmation(
        context,
        onConfirm: () => NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'mutation'),
        onCancel: () => _scannerController.start(),
      );
    } else {
      _scannerController.stop();
      NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'mutation');
    }
  }

  Future<bool> _onWillPop() async {
    if (_scannedBarcodes.isEmpty) {
      _scannerController.stop();
      return true;
    }
    
    _scannerController.stop();
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
          'Anda memiliki ${_scannedBarcodes.length} barcode yang belum di-submit.\n\nApakah Anda yakin ingin keluar?',
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
    
    final shouldPop = result ?? false;
    if (!shouldPop) {
      _scannerController.start();
    }
    return shouldPop;
  }

  void _showExitConfirmation(BuildContext context, {required VoidCallback onConfirm, required VoidCallback onCancel}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Peringatan'),
          ],
        ),
        content: Text(
          'Anda memiliki ${_scannedBarcodes.length} barcode yang belum di-submit.\n\nApakah Anda yakin ingin pindah menu?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel();
            },
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
        break;
      }
    }
  }

  Future<void> _handleBarcodeScanned(String barcode) async {
    final cleanedBarcode = barcode.trim();
    
    // Step 1: Handle Rack Scanning if no active rack
    if (_activeRack == null) {
      final rack = _racks.firstWhere(
        (r) => r.code.toLowerCase() == cleanedBarcode.toLowerCase() || r.id == cleanedBarcode,
        orElse: () => Rack(id: '', code: '', name: '', warehouseId: ''),
      );

      if (rack.id.isNotEmpty) {
        setState(() {
          _activeRack = rack;
        });
        SoundService().playSuccess();
        Toast.show(context, '✅ Rak terpilih: ${rack.displayName}');
      } else {
        SoundService().playError();
        Toast.show(context, '⚠️ Barcode bukan QR Rak yang valid');
      }
      return;
    }

    // Step 2: Handle Item Scanning
    if (_scannedBarcodes.any((b) => b.barcode == cleanedBarcode)) {
      SoundService().playError();
      Toast.show(context, '⚠️ Barcode sudah ada di daftar');
      return;
    }

    // Stop scanner while validating
    _scannerController.stop();

    try {
      final result = await MutationService.validateBarcode(cleanedBarcode);
      
      if (result['success']) {
        final data = result['data'];
        final model = data['model'];
        final color = data['color'];
        final size = data['size'];
        
        final modelName = model['name'] ?? model['sku'];
        final colorName = color['name'] ?? color['code'];
        final sizeCode = size['name'] ?? size['code'];

        final barcodeProduct = bp.BarcodeProduct(
          barcode: cleanedBarcode,
          type: bp.BarcodeType.satuan,
          model: modelName,
          warna: colorName,
          size: sizeCode,
          rak: '', 
          rackId: _activeRack!.id,
          qty: 1,
        ).markAsScanned();

        setState(() {
          _scannedBarcodes.insert(0, barcodeProduct);
        });

        SoundService().playSuccess();
        Toast.show(context, '✅ Item ditambahkan ke ${_activeRack!.code}');
      } else {
        SoundService().playError();
        Toast.show(context, '❌ ${result['message']}');
      }
    } catch (e) {
      SoundService().playError();
      Toast.show(context, '❌ Error validasi: $e');
    } finally {
      // Resume scanner
      _scannerController.start();
    }
  }


  void _removeBarcode(bp.BarcodeProduct barcode) {
    setState(() {
      _scannedBarcodes.remove(barcode);
    });
    Toast.show(context, 'Item dihapus');
  }

  void _clearAllBarcodes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Semua'),
        content: Text('Apakah Anda yakin ingin menghapus semua item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          TextButton(
            onPressed: () {
              setState(() => _scannedBarcodes.clear());
              Navigator.pop(context);
            },
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitMutation() async {
    if (_scannedBarcodes.isEmpty) {
      Toast.show(context, 'Belum ada item yang di-scan');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Group barcodes by rack_id
      final Map<String, List<String>> groupedItems = {};
      for (final item in _scannedBarcodes) {
        if (item.rackId != null) {
          groupedItems.putIfAbsent(item.rackId!, () => []).add(item.barcode);
        }
      }

      final List<Map<String, dynamic>> submitItems = groupedItems.entries.map((e) => {
        'rack_id': e.key,
        'barcodes': e.value,
      }).toList();

      final result = await MutationService.submitMutation(
        items: submitItems,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (result['success']) {
        _showSuccessDialog(result['data']);
      } else {
        _showErrorDialog(result['message'], result['data']);
      }
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic>? data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Berhasil'),
        content: Text('Mutasi berhasil diproses.\nTotal: ${data?['total_scanned'] ?? 0} item'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _scannedBarcodes.clear();
                _notesController.clear();
                _activeRack = null;
              });
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message, dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gagal'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _scannedBarcodes.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
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
          title: Text('MUTASI BARANG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.history, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MutationListScreen())),
            ),
            if (_scannedBarcodes.isNotEmpty)
              IconButton(icon: Icon(Icons.delete_sweep, color: Colors.white), onPressed: _clearAllBarcodes),
          ],
        ),
        drawer: AppDrawer(onMenuSelected: (menu) => _handleMenuSelection(context, menu)),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  MobileScanner(controller: _scannerController, onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 250, height: 250,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Positioned(
                    top: 20, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: _activeRack == null ? Colors.orange.withOpacity(0.8) : Colors.black.withOpacity(0.6),
                      child: Text(
                        _activeRack == null ? 'MOHON SCAN QR RAK DULU' : 'SCAN BARCODE BARANG (Rak: ${_activeRack!.code})', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  if (_activeRack != null)
                    Positioned(
                      top: 60, right: 16,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _activeRack = null),
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text('Ganti Rak', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Total: ${_scannedBarcodes.length} item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isListExpanded = !_isListExpanded),
                      child: Container(
                        padding: EdgeInsets.all(16), color: Colors.white,
                        child: Row(
                          children: [
                            Icon(_isListExpanded ? Icons.expand_more : Icons.chevron_right, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Text('Daftar Mutasi (${_scannedBarcodes.length})', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    if (_isListExpanded)
                      Expanded(
                        child: _scannedBarcodes.isEmpty
                            ? Center(child: Text('Mulai scan barcode...', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: EdgeInsets.all(8),
                                itemCount: _scannedBarcodes.length,
                                itemBuilder: (context, index) => _buildItemCard(_scannedBarcodes[index]),
                              ),
                      ),
                    Container(
                      color: Colors.white, padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _notesController,
                            decoration: InputDecoration(hintText: 'Catatan (opsional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submitMutation,
                              icon: _isSubmitting ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.send),
                              label: Text(_isSubmitting ? 'Memproses...' : 'Submit Mutasi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
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

  Widget _buildItemCard(bp.BarcodeProduct item) {
    final rack = _racks.firstWhere((r) => r.id == item.rackId, orElse: () => Rack(id: '', code: '', name: 'Unknown', warehouseId: ''));
    
    return Card(
      elevation: 1, margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.displayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('Ke: ${rack.displayName}', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
        trailing: IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => _removeBarcode(item)),
      ),
    );
  }
}
