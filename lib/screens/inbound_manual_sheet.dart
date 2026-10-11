import 'dart:async';

import 'package:flutter/material.dart';

import '../api/inbound_service.dart';
import '../components/toast.dart';
import '../models/manual_receive_item.dart';

/// Bottom sheet to add goods received WITHOUT a QR code: pick the request line,
/// the kind (returned unsewn good/defect, or extra sewn) and the quantity.
/// [queuedReturned] returns the returned-goods qty already queued for a line, so
/// the sheet can stop the user from returning more than what is outstanding.
Future<ManualReceiveItem?> showInboundManualSheet(
  BuildContext context, {
  required int Function(String lineId) queuedReturned,
}) {
  return showModalBottomSheet<ManualReceiveItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _InboundManualSheet(queuedReturned: queuedReturned),
  );
}

class _InboundManualSheet extends StatefulWidget {
  final int Function(String lineId) queuedReturned;

  const _InboundManualSheet({required this.queuedReturned});

  @override
  State<_InboundManualSheet> createState() => _InboundManualSheetState();
}

class _InboundManualSheetState extends State<_InboundManualSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  Timer? _debounce;

  List<InboundRequestLine> _lines = [];
  InboundRequestLine? _selected;
  ManualCategory _category = ManualCategory.returnedGood;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await InboundService.getRequestLines(search: _searchController.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = (result['data'] as List<dynamic>? ?? []);
        _lines = data
            .map((e) => InboundRequestLine.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _lines = [];
        _error = result['message']?.toString() ?? 'Gagal memuat baris permintaan';
      }
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _add() {
    final line = _selected;
    final qty = int.tryParse(_qtyController.text.trim());
    if (line == null) {
      Toast.show(context, 'Pilih baris permintaan terlebih dahulu', isError: true);
      return;
    }
    if (qty == null || qty < 1) {
      Toast.show(context, 'Jumlah harus bilangan bulat minimal 1', isError: true);
      return;
    }
    if (_category != ManualCategory.extra) {
      final left = line.outstandingQty - widget.queuedReturned(line.id);
      if (qty > left) {
        Toast.show(context, 'Jumlah kembali melebihi sisa permintaan ($left)', isError: true);
        return;
      }
    }
    Navigator.pop(
      context,
      ManualReceiveItem(line: line, category: _category, qty: qty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terima Tanpa QR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari serial, CMT, atau model',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _lines.isEmpty
                          ? const Center(child: Text('Tidak ada baris permintaan terbuka'))
                          : ListView.builder(
                              itemCount: _lines.length,
                              itemBuilder: (context, index) {
                                final line = _lines[index];
                                final selected = _selected?.id == line.id;
                                return ListTile(
                                  dense: true,
                                  selected: selected,
                                  selectedTileColor: Colors.blue.shade50,
                                  title: Text(line.label),
                                  subtitle: Text(
                                    'Diminta ${line.reqQty} · diterima ${line.recQty} · kembali ${line.recBsQty} · sisa ${line.outstandingQty}',
                                  ),
                                  trailing: selected
                                      ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                                      : null,
                                  onTap: () => setState(() => _selected = line),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ManualCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Jenis',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: ManualCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                _category.hint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah (pcs)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
