import 'package:flutter/material.dart';
import '../api/rack_service.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import 'barcode_scanner_screen.dart';

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  State<StockCheckScreen> createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  RackStock? _stock;
  String? _error;
  bool _loading = false;

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(
      context,
      menu,
      currentScreen: 'stock_check',
    );
  }

  Future<void> _scanRack() async {
    var handled = false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerContext) => BarcodeScannerScreen(
          title: 'Scan QR Rak',
          instruction: 'Arahkan kamera ke QR Code rak',
          scanType: ScanType.qrCode,
          onScanResult: (code) async {
            if (handled) return;
            handled = true;
            Navigator.pop(scannerContext);
            await _loadStock(code.trim());
          },
        ),
      ),
    );
  }

  Future<void> _loadStock(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stock = await RackService.getStockByCode(code);
      if (!mounted) return;
      setState(() {
        _stock = stock;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stock = null;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Cek Stok',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(onMenuSelected: _handleMenuSelection),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _scanRack,
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan Rak', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _placeholder(Icons.error_outline, _error!, Colors.red.shade300);
    }

    final stock = _stock;
    if (stock == null) {
      return _placeholder(
        Icons.qr_code_scanner,
        'Scan QR Code rak untuk melihat stok di rak tersebut',
        Colors.blue.shade200,
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stock.code} - ${stock.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (stock.warehouse != null)
                      Text(
                        stock.warehouse!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${stock.total}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Text('Total pcs', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: stock.items.isEmpty
              ? _placeholder(
                  Icons.inventory_2_outlined,
                  'Tidak ada stok di rak ini',
                  Colors.grey.shade400,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: stock.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _itemCard(stock.items[i]),
                ),
        ),
      ],
    );
  }

  Widget _itemCard(RackStockItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.model,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.color} • ${item.size}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Text(
            '${item.quantity} pcs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(IconData icon, String text, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
