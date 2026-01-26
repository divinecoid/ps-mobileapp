import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/inbound_service.dart';
import '../models/inbound_receive.dart';
import '../components/toast.dart';

class InboundDetailScreen extends StatefulWidget {
  final String inboundId;

  const InboundDetailScreen({
    super.key,
    required this.inboundId,
  });

  @override
  State<InboundDetailScreen> createState() => _InboundDetailScreenState();
}

class _InboundDetailScreenState extends State<InboundDetailScreen> {
  InboundReceive? _inbound;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadInboundDetail();
  }

  Future<void> _loadInboundDetail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('📦 Loading inbound detail: ${widget.inboundId}');
      final result = await InboundService.getInboundById(widget.inboundId);
      
      if (result['success'] == true && result['data'] != null) {
        final inbound = InboundReceive.fromJson(result['data'] as Map<String, dynamic>);
        
        if (mounted) {
          setState(() {
            _inbound = inbound;
            _isLoading = false;
          });
        }
        print('✅ Loaded inbound detail');
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
      print('❌ Error loading inbound detail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _copyBarcode(String barcode) {
    Clipboard.setData(ClipboardData(text: barcode));
    Toast.show(context, 'Barcode disalin: $barcode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _inbound?.cmtCode ?? 'Detail Penerimaan',
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
              'Memuat detail...',
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
                onPressed: _loadInboundDetail,
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

    if (_inbound == null) {
      return Center(child: Text('Data tidak ditemukan'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CMT Information Card
          _buildCmtInfoCard(),
          
          SizedBox(height: 16),
          
          // Receipt Information Card
          _buildReceiptInfoCard(),
          
          SizedBox(height: 16),
          
          // Barcodes List
          _buildBarcodesSection(),
          
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCmtInfoCard() {
    final cmt = _inbound!.cmtInfo;
    
    return Card(
      elevation: 2,
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
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi CMT',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        cmt?.name ?? '-',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (cmt != null) ...[
              SizedBox(height: 16),
              Divider(height: 1),
              SizedBox(height: 16),
              
              _buildInfoRow(Icons.qr_code, 'Kode', cmt.code),
              
              if (cmt.contactPerson != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(Icons.person, 'Contact Person', cmt.contactPerson!),
              ],
              
              if (cmt.phone != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(Icons.phone, 'Telepon', cmt.phone!),
              ],
              
              if (cmt.address != null) ...[
                SizedBox(height: 12),
                _buildInfoRow(Icons.location_on, 'Alamat', cmt.address!, maxLines: 3),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptInfoCard() {
    return Card(
      elevation: 2,
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
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Informasi Penerimaan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            Divider(height: 1),
            SizedBox(height: 16),
            
            _buildInfoRow(Icons.calendar_today, 'Tanggal', _inbound!.formattedDateShort),
            SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Waktu', _inbound!.formattedTime),
            
            if (_inbound!.warehouseName != null) ...[
              SizedBox(height: 12),
              _buildInfoRow(Icons.warehouse, 'Warehouse', _inbound!.warehouseName!),
            ],
            
            SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Diterima Oleh', _inbound!.userName),
            
            SizedBox(height: 12),
            _buildInfoRow(Icons.inventory_2, 'Total Items', '${_inbound!.totalItems} barcode'),
            
            if (_inbound!.notes != null && _inbound!.notes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.amber.shade700),
                        SizedBox(width: 6),
                        Text(
                          'Catatan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      _inbound!.notes!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey.shade700),
              SizedBox(width: 8),
              Text(
                'Daftar Barcode (${_inbound!.totalItems})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 12),
        
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _inbound!.details.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final detail = _inbound!.details[index];
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  detail.barcode,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade800,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade600),
                  onPressed: () => _copyBarcode(detail.barcode),
                  tooltip: 'Salin barcode',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
