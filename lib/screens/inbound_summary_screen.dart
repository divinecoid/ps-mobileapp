import 'package:flutter/material.dart';
import '../models/barcode_product.dart';

class InboundSummaryScreen extends StatelessWidget {
  final List<BarcodeProduct> scannedBarcodes;

  const InboundSummaryScreen({
    super.key,
    required this.scannedBarcodes,
  });

  // Group barcodes by model-warna-size-rak
  Map<String, List<BarcodeProduct>> _groupBarcodes() {
    final Map<String, List<BarcodeProduct>> grouped = {};

    for (final barcode in scannedBarcodes) {
      final key = '${barcode.model}|${barcode.warna}|${barcode.size}|${barcode.rak}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(barcode);
    }

    return grouped;
  }

  int _getTotalQtyForGroup(List<BarcodeProduct> barcodes) {
    return barcodes.fold(0, (sum, barcode) => sum + barcode.qty);
  }

  int get _totalItems {
    return scannedBarcodes.fold(0, (sum, barcode) => sum + barcode.qty);
  }

  int get _totalBarcodes {
    return scannedBarcodes.length;
  }

  int get _totalLusin {
    return scannedBarcodes.where((b) => b.type == BarcodeType.lusin).length;
  }

  int get _totalSatuan {
    return scannedBarcodes.where((b) => b.type == BarcodeType.satuan).length;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupBarcodes();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: Text(
          'Summary Inbound',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Overall Summary Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Ringkasan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Barcode',
                        '$_totalBarcodes',
                        Icons.qr_code_scanner,
                        Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Item',
                        '$_totalItems',
                        Icons.inventory_2,
                        Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Lusin',
                        '$_totalLusin',
                        Icons.layers,
                        Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Satuan',
                        '$_totalSatuan',
                        Icons.style,
                        Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Grouped List
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.list, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Text(
                  'Detail per Group (${grouped.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // List of Groups
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      final key = entry.key;
                      final barcodes = entry.value;
                      final parts = key.split('|');
                      final model = parts[0];
                      final warna = parts[1];
                      final size = parts[2];
                      final rak = parts[3];
                      final totalQty = _getTotalQtyForGroup(barcodes);

                      return _buildGroupCard(
                        context,
                        model: model,
                        warna: warna,
                        size: size,
                        rak: rak,
                        barcodes: barcodes,
                        totalQty: totalQty,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color textColor,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context, {
    required String model,
    required String warna,
    required String size,
    required String rak,
    required List<BarcodeProduct> barcodes,
    required int totalQty,
  }) {
    final lusinCount = barcodes.where((b) => b.type == BarcodeType.lusin).length;
    final satuanCount = barcodes.where((b) => b.type == BarcodeType.satuan).length;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2,
            color: Colors.blue.shade700,
            size: 24,
          ),
        ),
        title: Text(
          '$model - $warna - $size',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.warehouse, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  'Rak: $rak',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.qr_code_scanner, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(
                  '${barcodes.length} barcode • Total: $totalQty item',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(
                      'Lusin: $lusinCount',
                      Colors.orange,
                      Icons.layers,
                    ),
                    _buildBadge(
                      'Satuan: $satuanCount',
                      Colors.purple,
                      Icons.style,
                    ),
                    _buildBadge(
                      'Total: $totalQty item',
                      Colors.green,
                      Icons.inventory_2,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Detail Barcode:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                ...barcodes.map((barcode) => _buildBarcodeListItem(barcode)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeListItem(BarcodeProduct barcode) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: barcode.type == BarcodeType.lusin
                  ? Colors.orange.shade100
                  : Colors.purple.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              barcode.type == BarcodeType.lusin ? Icons.layers : Icons.style,
              size: 16,
              color: barcode.type == BarcodeType.lusin
                  ? Colors.orange.shade900
                  : Colors.purple.shade900,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barcode.barcode,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Qty: ${barcode.qty}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(width: 12),
                    if (barcode.scannedAt != null)
                      Text(
                        _formatDateTime(barcode.scannedAt!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
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

