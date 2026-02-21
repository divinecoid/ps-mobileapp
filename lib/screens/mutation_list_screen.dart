import 'package:flutter/material.dart';
import '../api/mutation_service.dart';
import '../models/mutation.dart';
import '../components/toast.dart';
import 'mutation_detail_screen.dart';

class MutationListScreen extends StatefulWidget {
  const MutationListScreen({super.key});

  @override
  State<MutationListScreen> createState() => _MutationListScreenState();
}

class _MutationListScreenState extends State<MutationListScreen> {
  List<MutationRecord> _mutations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMutations();
  }

  Future<void> _loadMutations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await MutationService.getMutations(page: 1, limit: 50);
      
      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final mutations = data
            .map((json) => MutationRecord.fromJson(json as Map<String, dynamic>))
            .toList();
        
        if (mounted) {
          setState(() {
            _mutations = mutations;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = result['message'] ?? 'Failed to load data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadMutations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Riwayat Mutasi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            SizedBox(height: 16),
            Text('Gagal Memuat Data', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_errorMessage),
            SizedBox(height: 24),
            ElevatedButton(onPressed: _loadMutations, child: Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_mutations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            SizedBox(height: 16),
            Text('Belum Ada Mutasi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _mutations.length,
        itemBuilder: (context, index) => _buildMutationCard(_mutations[index]),
      ),
    );
  }

  Widget _buildMutationCard(MutationRecord mutation) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MutationDetailScreen(mutation: mutation),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mutasi #${mutation.id.substring(0, 8)}', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${mutation.formattedDateShort} • ${mutation.formattedTime}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('${mutation.totalItems} Items', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (mutation.notes != null && mutation.notes!.isNotEmpty) ...[
                SizedBox(height: 12),
                Text('Catatan: ${mutation.notes}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
