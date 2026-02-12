import 'package:flutter/material.dart';
import '../api/inbound_service.dart';
import '../models/inbound_receive.dart';
import '../components/toast.dart';
import 'inbound_detail_screen.dart';

class InboundListScreen extends StatefulWidget {
  const InboundListScreen({super.key});

  @override
  State<InboundListScreen> createState() => _InboundListScreenState();
}

class _InboundListScreenState extends State<InboundListScreen> {
  List<InboundReceive> _inbounds = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadInbounds();
  }

  Future<void> _loadInbounds() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('📦 Loading inbounds...');
      // Load first page with large limit for now
      final result = await InboundService.getInbounds(page: 1, limit: 50);
      
      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final inbounds = data
            .map((json) => InboundReceive.fromJson(json as Map<String, dynamic>))
            .toList();
        
        if (mounted) {
          setState(() {
            _inbounds = inbounds;
            _isLoading = false;
          });
        }
        print('✅ Loaded ${inbounds.length} inbounds');
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
      print('❌ Error loading inbounds: $e');
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
    await _loadInbounds();
  }

  void _navigateToDetail(InboundReceive inbound) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InboundDetailScreen(inboundId: inbound.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Daftar Penerimaan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Memuat data...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              SizedBox(height: 16),
              Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInbounds,
                icon: Icon(Icons.refresh),
                label: Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_inbounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16),
            Text(
              'Belum Ada Penerimaan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Data penerimaan akan muncul di sini',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _inbounds.length,
        itemBuilder: (context, index) {
          final inbound = _inbounds[index];
          return _buildInboundCard(inbound);
        },
      ),
    );
  }

  Widget _buildInboundCard(InboundReceive inbound) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(inbound),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: CMT Info
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inbound.cmtDisplayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 2),
                        if (inbound.warehouseName != null)
                          Row(
                            children: [
                              Icon(Icons.warehouse, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                inbound.warehouseName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),

              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),

              // Info Row
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.calendar_today,
                      label: inbound.formattedDateShort,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.access_time,
                      label: inbound.formattedTime,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.inventory_2,
                      label: '${inbound.totalItems} items',
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.person,
                      label: inbound.userName,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),

              // Notes if available
              if (inbound.notes != null && inbound.notes!.isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          inbound.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.shade700,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
