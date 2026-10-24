import 'package:flutter/material.dart';
import '../api/manual_outbound_service.dart';
import '../components/toast.dart';

class ManualOutboundHistoryScreen extends StatefulWidget {
  const ManualOutboundHistoryScreen({super.key});

  @override
  State<ManualOutboundHistoryScreen> createState() =>
      _ManualOutboundHistoryScreenState();
}

class _ManualOutboundHistoryScreenState
    extends State<ManualOutboundHistoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ManualOutboundService.getHistory();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _rows = List<Map<String, dynamic>>.from(result['data'] ?? []);
      } else {
        _error = result['message']?.toString() ?? 'Gagal memuat riwayat';
      }
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final result = await ManualOutboundService.getDetail(row['id'].toString());
    if (!mounted) return;
    if (result['success'] != true) {
      Toast.show(context, '❌ ${result['message']}', isError: true);
      return;
    }
    final detail = Map<String, dynamic>.from(result['data']);
    final summary = List<Map<String, dynamic>>.from(detail['summary'] ?? []);
    final notes = (detail['notes'] ?? '').toString().trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Detail Outbound Manual',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _kv('Tanggal', _formatDate(detail['outbound_date'])),
            _kv('Marketplace',
                detail['marketplace']?['name'] ?? 'Tanpa Marketplace'),
            _kv('Petugas', detail['user']?['name'] ?? '-'),
            _kv('Total Barang', '${detail['total_items']} items'),
            _kv('Catatan', notes.isEmpty ? '-' : notes),
            const Divider(height: 24),
            const Text('Ringkasan',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final s in summary)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${s['model'] ?? '-'}'),
                subtitle: Text('${s['color'] ?? '-'} • ${s['size'] ?? '-'}'),
                trailing: Text('${s['qty']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: TextStyle(color: Colors.grey.shade600))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Riwayat Outbound Manual',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Belum ada outbound manual'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
          final notes = (r['notes'] ?? '').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              onTap: () => _openDetail(r),
              leading: Icon(Icons.output, color: Colors.red.shade700),
              title: Text(r['marketplace']?['name'] ?? 'Tanpa Marketplace',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${_formatDate(r['outbound_date'])} • ${r['user']?['name'] ?? '-'}'
                  '${notes.isNotEmpty ? '\n$notes' : ''}'),
              isThreeLine: notes.isNotEmpty,
              trailing: Text('${r['total_items']} item',
                  style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}
