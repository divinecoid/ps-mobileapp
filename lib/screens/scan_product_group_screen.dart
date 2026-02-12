import 'package:flutter/material.dart';
import '../models/grouped_product_item.dart';
import '../models/scanned_barcode.dart';
import '../components/toast.dart';
import '../api/order_service.dart';
import 'barcode_scanner_screen.dart';

class ScanProductGroupScreen extends StatefulWidget {
  final GroupedProductItem productGroup;
  final Function(GroupedProductItem) onGroupComplete;

  const ScanProductGroupScreen({
    super.key,
    required this.productGroup,
    required this.onGroupComplete,
  });

  @override
  State<ScanProductGroupScreen> createState() => _ScanProductGroupScreenState();
}

class _ScanProductGroupScreenState extends State<ScanProductGroupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late GroupedProductItem _currentGroup;
  late GroupedProductItem _originalGroup; // Backup of original state
  bool _isLoading = false;
  Function(String, {bool isError})?
  _showScannerToast; // Callback to show toast in scanner

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentGroup = widget.productGroup;
    _originalGroup = widget.productGroup; // Save original state
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startContinuousScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          title: 'Scan QR Code Produk',
          instruction:
              'Scan QR code untuk ${_currentGroup.displayName}\n${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity} ter-scan',
          scanType: ScanType.qrCode,
          onScanResult: (barcode) async {
            // Process barcode without closing scanner
            await _validateAndAddBarcode(barcode);
          },
          scannedBarcodes: _currentGroup.scannedBarcodes,
          onInstructionUpdate: () {
            // Return updated instruction after scan
            return 'Scan QR code untuk ${_currentGroup.displayName}\n${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity} ter-scan';
          },
          onError: (showToast) {
            // Store toast callback for showing errors
            _showScannerToast = showToast as Function(String, {bool isError})?;
          },
        ),
      ),
    );

    // Clear callback when scanner closes
    _showScannerToast = null;
  }

  Future<void> _validateAndAddBarcode(String barcode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 0. Check if quantity is already fulfilled
      if (_currentGroup.scannedCount >= _currentGroup.requiredQuantity) {
        _showScannerToast?.call(
          '⚠️ Quantity sudah terpenuhi! (${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity})',
          isError: true,
        );
        return;
      }

      // 1. Parse barcode
      final scannedBarcode = ScannedBarcode.fromBarcode(barcode);

      if (scannedBarcode == null) {
        _showScannerToast?.call('Format barcode tidak valid', isError: true);
        return;
      }

      if (scannedBarcode.isGroup()) {
        _showScannerToast?.call(
          'Barcode tidak sesuai! Tidak boleh ada barcode group',
          isError: true,
        );
        return;
      }

      if (!scannedBarcode.matchesVariant(
        _currentGroup.sku,
        _currentGroup.color,
        _currentGroup.size,
      )) {
        _showScannerToast?.call(
          'Barcode tidak sesuai! Expected: ${_currentGroup.displayName}',
          isError: true,
        );
        return;
      }

      // 3. Check for duplicate barcode in current group
      if (_currentGroup.scannedBarcodes.contains(barcode)) {
        _showScannerToast?.call(
          'Barcode sudah di-scan sebelumnya!',
          isError: true,
        );
        return;
      }

      // 4. Validate with backend API
      final response = await OrderService.validateProductBarcode(barcode);

      if (!mounted) return;

      if (response['success'] == true) {
        // Add barcode to scanned list
        final newScannedCount = _currentGroup.scannedBarcodes.length + 1;
        final isNowComplete = newScannedCount == _currentGroup.requiredQuantity;

        setState(() {
          _currentGroup = _currentGroup.copyWith(
            scannedBarcodes: [..._currentGroup.scannedBarcodes, barcode],
            isComplete: isNowComplete,
          );
        });

        // Show appropriate toast message
        // Show appropriate toast message
        if (isNowComplete) {
          _showScannerToast?.call(
            '✅ Seluruh jumlah item sudah terpenuhi! (${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity})',
            isError: false,
          );
        } else {
          _showScannerToast?.call(
            'Barcode berhasil di-scan! (${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity})',
            isError: false,
          );
        }
      } else {
        _showScannerToast?.call(
          response['message'] ?? 'Barcode tidak valid di backend',
          isError: true,
        );
      }
    } catch (e) {
      _showScannerToast?.call(
        'Error: Gagal memvalidasi barcode',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _removeBarcode(int index) {
    setState(() {
      final updatedBarcodes = List<String>.from(_currentGroup.scannedBarcodes);
      updatedBarcodes.removeAt(index);

      _currentGroup = _currentGroup.copyWith(
        scannedBarcodes: updatedBarcodes,
        isComplete: updatedBarcodes.length == _currentGroup.requiredQuantity,
      );
    });

    Toast.show(context, 'Barcode dihapus');
  }

  void _submitGroup() {
    if (_currentGroup.isGroupComplete) {
      widget.onGroupComplete(_currentGroup);
      Navigator.pop(context);
      Toast.show(context, 'Grup ${_currentGroup.displayName} selesai di-scan');
    } else {
      Toast.show(
        context,
        'Belum semua barang di-scan! (${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity})',
      );
    }
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
            Expanded(
              child: Text(
                'Batalkan Scan?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan scan grup ini?',
              style: TextStyle(fontSize: 16),
            ),
            if (_currentGroup.scannedBarcodes.isNotEmpty) ...[
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
                        'List barang yang sudah diedit akan dikembalikan ke kondisi sebelumnya',
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
              Navigator.of(context).pop(); // Close dialog
              // Restore original state
              setState(() {
                _currentGroup = _originalGroup;
              });
              Navigator.of(context).pop(); // Close scan screen
              Toast.show(
                context,
                'Perubahan dibatalkan, data dikembalikan ke kondisi awal',
              );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _currentGroup.scannedBarcodes.isEmpty
              ? () => Navigator.pop(context)
              : _showCancelConfirmation,
        ),
        title: Text(
          'Scan ${_currentGroup.displayName}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scanner'),
            Tab(
              icon: Icon(Icons.list),
              text: 'Scanned (${_currentGroup.scannedCount})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildScannerTab(), _buildScannedItemsTab()],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _currentGroup.isGroupComplete
                      ? _submitGroup
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    _currentGroup.isGroupComplete
                        ? 'SUBMIT (${_currentGroup.scannedCount}/${_currentGroup.requiredQuantity})'
                        : 'Scan ${_currentGroup.requiredQuantity - _currentGroup.scannedCount} lagi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _showCancelConfirmation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red, width: 2),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'BATAL',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Info Card
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
                      Icon(Icons.inventory_2, color: Colors.blue, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Produk yang harus di-scan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentGroup.displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Scanned: ${_currentGroup.scannedCount} / ${_currentGroup.requiredQuantity}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          // Success indicator when quantity is fulfilled
          if (_currentGroup.isGroupComplete) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.green.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity Terpenuhi!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Semua ${_currentGroup.requiredQuantity} item sudah ter-scan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
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
          ],
          // Scanner Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _currentGroup.isGroupComplete
                  ? null
                  : _startContinuousScan,
              icon: Icon(Icons.qr_code_scanner, size: 32),
              label: Text(
                _currentGroup.isGroupComplete
                    ? 'QUANTITY TERPENUHI'
                    : 'SCAN QR CODE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentGroup.isGroupComplete
                    ? Colors.grey
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Instructions
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
                      Icon(Icons.info_outline, color: Colors.orange, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Instruksi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildInstructionItem(
                    '1',
                    'Klik tombol "SCAN QR CODE" di atas',
                  ),
                  _buildInstructionItem(
                    '2',
                    'Arahkan kamera ke QR code produk',
                  ),
                  _buildInstructionItem(
                    '3',
                    'Pastikan QR code sesuai dengan variant ${_currentGroup.displayName}',
                  ),
                  _buildInstructionItem(
                    '4',
                    'Scan sebanyak ${_currentGroup.requiredQuantity} item',
                  ),
                  _buildInstructionItem(
                    '5',
                    'Klik "SUBMIT GRUP" setelah semua item ter-scan',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedItemsTab() {
    if (_currentGroup.scannedBarcodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 80, color: Colors.grey.shade300),
            SizedBox(height: 16),
            Text(
              'Belum ada barcode yang di-scan',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Klik tab "Scanner" untuk mulai scan',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _currentGroup.scannedBarcodes.length,
      itemBuilder: (context, index) {
        final barcode = _currentGroup.scannedBarcodes[index];
        final scannedItem = ScannedBarcode.fromBarcode(barcode);

        return Dismissible(
          key: Key(barcode),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.delete, color: Colors.white, size: 32),
          ),
          onDismissed: (direction) {
            _removeBarcode(index);
          },
          child: Card(
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ),
              title: Text(
                barcode,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: scannedItem != null
                  ? Text(
                      '${scannedItem.sku} - ${scannedItem.color} - ${scannedItem.size}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  : null,
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeBarcode(index),
              ),
            ),
          ),
        );
      },
    );
  }
}
