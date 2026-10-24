import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/app_drawer.dart';
import '../components/toast.dart';
import '../utils/navigation_helper.dart';
import '../utils/sound_service.dart';
import '../api/manual_outbound_service.dart';
import '../api/marketplace_service.dart';
import 'manual_outbound_history_screen.dart';

/// Satu barcode piece yang sudah lolos validasi API.
class _ScannedPiece {
  final String barcode;
  final String model;
  final String color;
  final String size;
  final String? rack;
  final String groupKey; // model_id|color_id|size_id

  _ScannedPiece({
    required this.barcode,
    required this.model,
    required this.color,
    required this.size,
    required this.rack,
    required this.groupKey,
  });
}

class ManualOutboundScreen extends StatefulWidget {
  const ManualOutboundScreen({super.key});

  @override
  State<ManualOutboundScreen> createState() => _ManualOutboundScreenState();
}

class _ManualOutboundScreenState extends State<ManualOutboundScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  final List<_ScannedPiece> _pieces = [];
  bool _isValidating = false;
  bool _isSubmitting = false;
  bool _showBarcodes = false; // false = ringkasan, true = daftar barcode

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // Ringkasan per model|warna|ukuran, urutan scan dipertahankan.
  List<MapEntry<String, List<_ScannedPiece>>> get _groups {
    final map = <String, List<_ScannedPiece>>{};
    for (final p in _pieces) {
      map.putIfAbsent(p.groupKey, () => []).add(p);
    }
    return map.entries.toList();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _handleScanned(code);
        break;
      }
    }
  }

  Future<void> _handleScanned(String raw) async {
    if (_isValidating || _isSubmitting) return;
    final code = raw.trim();
    if (code.isEmpty) return;

    if (_pieces.any((p) => p.barcode == code)) {
      SoundService().playError();
      Toast.show(context, '⚠️ Barcode sudah di-scan!', isError: true);
      return;
    }

    _isValidating = true;
    try {
      final result = await ManualOutboundService.validateBarcode(code);
      if (!mounted) return;
      if (result['success'] == true) {
        final product = result['data']['product'];
        final model = product['model'];
        final color = product['color'];
        final size = product['size'];
        final rack = product['rack'];
        final piece = _ScannedPiece(
          barcode: code,
          model: model?['name'] ?? '-',
          color: color?['name'] ?? '-',
          size: size?['name'] ?? '-',
          rack: rack != null ? '${rack['code']} - ${rack['name']}' : null,
          groupKey: '${model?['id'] ?? ''}|${color?['id'] ?? ''}|${size?['id'] ?? ''}',
        );
        setState(() => _pieces.insert(0, piece));
        SoundService().playSuccess();
        Toast.show(context,
            '✅ Barcode valid: ${piece.model} ${piece.color} ${piece.size}');
      } else {
        SoundService().playError();
        Toast.show(context, '❌ ${result['message']}', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      SoundService().playError();
      Toast.show(context, '❌ Error validasi: $e', isError: true);
    } finally {
      // Jeda singkat agar QR yang sama tidak langsung terbaca ulang.
      await Future.delayed(const Duration(milliseconds: 800));
      _isValidating = false;
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    _scannerController.stop();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    _scannerController.start();
    return result ?? false;
  }

  Future<void> _removeGroup(String key) async {
    final ok = await _confirm('Hapus semua barcode barang ini?',
        'Semua barcode untuk model/warna/ukuran ini akan dihapus dari daftar.', 'Hapus');
    if (ok && mounted) {
      setState(() => _pieces.removeWhere((p) => p.groupKey == key));
    }
  }

  Future<void> _removePiece(_ScannedPiece piece) async {
    final ok = await _confirm('Hapus barcode ini?',
        'Barcode ini akan dihapus dari daftar outbound.', 'Hapus');
    if (ok && mounted) setState(() => _pieces.remove(piece));
  }

  Future<void> _reset() async {
    final ok = await _confirm('Reset daftar?',
        'Semua barang yang sudah di-scan akan dihapus dari daftar.', 'Reset');
    if (ok && mounted) setState(() => _pieces.clear());
  }

  Future<bool> _confirmLeave(String what) async {
    if (_pieces.isEmpty) return true;
    return _confirm('Peringatan',
        'Anda memiliki ${_pieces.length} barcode yang belum di-submit.\n\nApakah Anda yakin ingin $what?',
        'Ya');
  }

  Future<void> _handleMenuSelection(BuildContext context, String menu) async {
    if (await _confirmLeave('pindah menu') && context.mounted) {
      _scannerController.stop();
      NavigationHelper.handleMenuSelection(context, menu,
          currentScreen: 'manual_outbound');
    }
  }

  Future<void> _openSubmitSheet() async {
    if (_pieces.isEmpty) {
      Toast.show(context, '⚠️ Tambahkan minimal 1 barcode terlebih dahulu!',
          isError: true);
      return;
    }
    _scannerController.stop();

    List<Map<String, dynamic>> marketplaces = [];
    try {
      marketplaces = await MarketplaceService.getMarketplaces();
    } catch (_) {
      if (mounted) {
        Toast.show(context,
            '⚠️ Daftar marketplace gagal dimuat, lanjut tanpa marketplace',
            isError: true);
      }
    }
    if (!mounted) return;

    final notesController = TextEditingController();
    String? marketplaceId;
    final groups = _groups;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Konfirmasi Outbound Manual',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    'Periksa ringkasan barang keluar sebelum submit. Stok akan langsung terpotong.',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                Text('Ringkasan (${_pieces.length} item)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in groups)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(g.value.first.model),
                          subtitle: Text(
                              '${g.value.first.color} • ${g.value.first.size}'),
                          trailing: Text('${g.value.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: marketplaceId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Marketplace (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Tanpa Marketplace')),
                    for (final m in marketplaces)
                      DropdownMenuItem<String?>(
                          value: m['id'].toString(),
                          child: Text('${m['name'] ?? m['alias'] ?? '-'}')),
                  ],
                  onChanged: (v) => setSheet(() => marketplaceId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white),
                        child: const Text('Submit & Potong Stok'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final notes = notesController.text.trim();
    notesController.dispose();

    if (confirmed == true && mounted) {
      await _submit(marketplaceId, notes);
    }
    if (mounted) _scannerController.start();
  }

  Future<void> _submit(String? marketplaceId, String notes) async {
    setState(() => _isSubmitting = true);
    try {
      final result = await ManualOutboundService.submit(
        barcodes: _pieces.map((p) => p.barcode).toList(),
        marketplaceId: marketplaceId,
        notes: notes,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        SoundService().playSuccess();
        setState(() => _pieces.clear());
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Berhasil'),
            content: Text(result['message'].toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
      } else {
        SoundService().playError();
        await _showErrorDialog(
            result['message'].toString(), result['data']);
      }
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showErrorDialog(String message, dynamic data) async {
    final invalid = <String>[
      if (data is Map) ...List<String>.from((data['invalid'] ?? []).map((e) => '$e')),
      if (data is Map) ...List<String>.from((data['scanned'] ?? []).map((e) => '$e')),
    ];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gagal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (invalid.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Barcode bermasalah:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final b in invalid)
                  Text(b, style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pieces.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave('keluar') && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('OUTBOUND MANUAL',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManualOutboundHistoryScreen())),
            ),
            if (_pieces.isNotEmpty)
              IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  onPressed: _reset),
          ],
        ),
        drawer: AppDrawer(
            onMenuSelected: (menu) => _handleMenuSelection(context, menu)),
        body: Column(
          children: [
            Expanded(flex: 2, child: _buildScanner()),
            Expanded(flex: 3, child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          fit: BoxFit.cover,
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black.withOpacity(0.6),
            child: const Text('SCAN QR BARANG SATUAN (PIECE)',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Total: ${_pieces.length} item di-scan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final groups = _groups;
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false, label: Text('Barang Keluar (${groups.length})')),
                ButtonSegment(
                    value: true, label: Text('Kode Batang (${_pieces.length})')),
              ],
              selected: {_showBarcodes},
              onSelectionChanged: (s) =>
                  setState(() => _showBarcodes = s.first),
            ),
          ),
          Expanded(
            child: _pieces.isEmpty
                ? const Center(
                    child: Text('Mulai scan barcode...',
                        style: TextStyle(color: Colors.grey)))
                : _showBarcodes
                    ? ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _pieces.length,
                        itemBuilder: (_, i) => _pieceCard(_pieces[i]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: groups.length,
                        itemBuilder: (_, i) => _groupCard(groups[i]),
                      ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _openSubmitSheet,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Memproses...' : 'Submit Outbound'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(MapEntry<String, List<_ScannedPiece>> g) {
    final first = g.value.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(first.model,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('${first.color} • ${first.size}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${g.value.length}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeGroup(g.key)),
          ],
        ),
      ),
    );
  }

  Widget _pieceCard(_ScannedPiece p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${p.model} ${p.color} ${p.size}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${p.barcode}${p.rack != null ? '\nRak: ${p.rack}' : ''}',
            style: const TextStyle(fontSize: 11)),
        isThreeLine: p.rack != null,
        trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removePiece(p)),
      ),
    );
  }
}
