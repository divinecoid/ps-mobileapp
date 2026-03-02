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
    if (_isLoading || _hasError || _inbound == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Detail Penerimaan'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: _buildLoadingOrError(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      _buildCmtInfoCard(),
                      SizedBox(height: 16),
                      _buildReceiptInfoCard(),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    tabs: [
                      Tab(text: 'DITERIMA'),
                      Tab(text: 'REJECT (BS)'),
                    ],
                    labelColor: Colors.blue.shade700,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue.shade700,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: Diterima
              _buildAcceptedTab(),
              // Tab 2: Reject
              _buildRejectedTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
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
    
    return Center(child: Text('Data tidak ditemukan'));
  }

  Widget _buildAcceptedTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Section (Accepted only)
          _buildAcceptedSummarySection(),
          
          SizedBox(height: 16),
          
          // Barcodes List (Accepted only)
          _buildAcceptedBarcodesSection(),
          
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRejectedTab() {
    final rejectedSummary = _inbound!.summary.where((s) => s.isReject).toList();
    
    if (rejectedSummary.isEmpty && _inbound!.rejectedDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
            SizedBox(height: 16),
            Text(
              'Tidak ada barang reject',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Section (Rejected only)
          _buildRejectedSummarySection(),
          
          SizedBox(height: 16),
          
          // Barcodes List (Rejected only)
          _buildRejectedBarcodesSection(),
          
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAcceptedSummarySection() {
    final acceptedSummary = _inbound!.summary.where((s) => !s.isReject).toList();
    if (acceptedSummary.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: 20, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(
                'Ringkasan Barang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        ...acceptedSummary.map((summary) => _buildSummaryCard(summary)).toList(),
      ],
    );
  }

  Widget _buildRejectedSummarySection() {
    final rejectedSummary = _inbound!.summary.where((s) => s.isReject).toList();
    if (rejectedSummary.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.report_problem, size: 20, color: Colors.red.shade700),
              SizedBox(width: 8),
              Text(
                'Ringkasan Barang (Reject)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        ...rejectedSummary.map((summary) => _buildSummaryCard(summary, isReject: true)).toList(),
      ],
    );
  }

  Widget _buildSummaryCard(InboundSummary summary, {bool isReject = false}) {
    final themeColor = isReject ? Colors.red : Colors.blue;
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: themeColor.shade100),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeColor.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${summary.totalQty}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeColor.shade700,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      if (isReject)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'REJECT (BS)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (summary.serialNumber != null && summary.serialNumber!.isNotEmpty)
                    Text(
                      'SN: ${summary.serialNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Text(
              'PCS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
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

  Widget _buildAcceptedBarcodesSection() {
    if (_inbound!.details.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 20, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(
                'Daftar Barcode (${_inbound!.details.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildBarcodeListCard(_inbound!.details, isReject: false, startIndex: 1),
      ],
    );
  }

  Widget _buildRejectedBarcodesSection() {
    if (_inbound!.rejectedDetails.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.report_gmailerrorred, size: 20, color: Colors.red.shade700),
              SizedBox(width: 8),
              Text(
                'Daftar Barcode Reject (${_inbound!.rejectedDetails.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildBarcodeListCard(_inbound!.rejectedDetails, isReject: true, startIndex: _inbound!.details.length + 1),
      ],
    );
  }

  Widget _buildBarcodeListCard(List<InboundReceiveDetail> items, {required bool isReject, int startIndex = 1}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isReject ? Colors.red.shade100 : Colors.transparent),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final detail = items[index];
          final displayIndex = startIndex + index;
          
          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isReject ? Colors.red.shade100 : Colors.purple.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$displayIndex',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isReject ? Colors.red.shade700 : Colors.purple.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    detail.barcode,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                if (isReject)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      'BS',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.model != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '${detail.model} - ${detail.color} - ${detail.size}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'Qty: ${detail.qty}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      if (detail.rack != null && detail.rack!.isNotEmpty) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            'Rak: ${detail.rack}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade600),
              onPressed: () => _copyBarcode(detail.barcode),
              tooltip: 'Salin barcode',
            ),
          );
        },
      ),
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey.shade50,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
