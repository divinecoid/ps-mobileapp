import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/checker_service.dart';
import '../components/app_drawer.dart';
import '../components/toast.dart';
import '../utils/navigation_helper.dart';

class CheckerScreen extends StatefulWidget {
  const CheckerScreen({super.key});

  @override
  State<CheckerScreen> createState() => _CheckerScreenState();
}

class _DialogRow {
  const _DialogRow(this.label, this.value);
  final String label;
  final String value;
}

class _CheckerScreenState extends State<CheckerScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _assignedOrders = [];
  List<dynamic> _orderItems = [];
  final List<Map<String, dynamic>> _scannedItems = [];
  final List<String> _scannedBarcodes = [];

  // Stats
  int _assignedCount = 0;
  int _todayCheckedCount = 0;
  int _pendingCount = 0;

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isProcessingScan = false;
  bool _torchEnabled = false;
  String _errorMessage = '';

  String? _selectedOrderId;
  Map<String, dynamic>? _selectedOrder;

  int _currentPage = 1;
  int _totalPages = 1;

  TabController? _tabController;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _loadAssignedOrders();
    // Pre-allocate tab controller to prevent null crashes during async loading
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(
      context,
      menu,
      currentScreen: 'checker',
    );
  }

  Future<void> _loadAssignedOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await CheckerService.getAssignedOrders(
        page: _currentPage,
        perPage: 15,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _assignedOrders
            ..clear()
            ..addAll((data['data'] as List?) ?? []);
          _totalPages = (data['last_page'] as num?)?.toInt() ?? 1;

          // Stats — use response meta if available, else derive from list
          _assignedCount =
              (data['total'] as num?)?.toInt() ?? _assignedOrders.length;
          _todayCheckedCount = (data['today_checked'] as num?)?.toInt() ?? 0;
          _pendingCount = (data['pending'] as num?)?.toInt() ?? 0;

          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Failed to load checker orders';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _openOrderForChecking(Map<String, dynamic> order) async {
    if (!mounted) return;

    setState(() {
      _selectedOrder = order;
      _selectedOrderId = order['id']?.toString();
      _isLoading = true;
      _errorMessage = '';
      _orderItems = [];
      _scannedItems.clear();
      _scannedBarcodes.clear();
    });

    try {
      final response = await CheckerService.getOrderItems(_selectedOrderId!);

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _orderItems = List<dynamic>.from(data['items'] ?? []);
          _isLoading = false;
        });
        _initializeScanner();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load order items';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isLoading = false;
      });
    }
  }

  void _initializeScanner() {
    _scannerController?.dispose();

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Reuse tab controller from initState, just ensure listener is set
    _tabController?.addListener(() {
      if (_tabController!.index == 0) {
        _scannerController?.start();
      } else {
        _scannerController?.stop();
      }
    });

    _scannerController?.start();
    setState(() => _torchEnabled = false);
  }

  void _toggleTorch() {
    _scannerController?.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  void _flipCamera() {
    _scannerController?.switchCamera();
  }

  String? _extractSequence(String barcode) {
    final parts = barcode.split('|');
    if (parts.length == 7) return '${parts[5]}-${parts[6]}';
    final regex = RegExp(r'[-_]?(\d{2,})$');
    final match = regex.firstMatch(barcode);
    return match?.group(1);
  }

  bool _isSequenceUnique(String sku, String sequence) {
    return !_scannedItems.any(
      (item) => item['sku'] == sku && item['sequence'] == sequence,
    );
  }

  int _requiredQtyForKey(String sku, String color, String size) {
    return _orderItems
        .where(
          (item) =>
              (item['sku']?.toString().toLowerCase() ?? '') ==
                  sku.toLowerCase() &&
              (item['color']?.toString().toLowerCase() ?? '') ==
                  color.toLowerCase() &&
              (item['size']?.toString().toLowerCase() ?? '') ==
                  size.toLowerCase(),
        )
        .length;
  }

  int _scannedQtyForKey(String sku, String color, String size) {
    return _scannedItems
        .where(
          (item) =>
              (item['sku']?.toString().toLowerCase() ?? '') ==
                  sku.toLowerCase() &&
              (item['color']?.toString().toLowerCase() ?? '') ==
                  color.toLowerCase() &&
              (item['size']?.toString().toLowerCase() ?? '') ==
                  size.toLowerCase(),
        )
        .length;
  }

  Future<void> _handleBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessingScan ||
        _tabController?.index != 0 ||
        _selectedOrderId == null)
      return;

    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    _isProcessingScan = true;

    try {
      final sequence = _extractSequence(code);
      if (sequence == null) {
        Toast.show(context, 'Barcode tidak valid: sequence tidak ditemukan');
        return;
      }

      final response = await CheckerService.validateProductBarcode(
        orderId: _selectedOrderId!,
        barcode: code,
      );

      if (!mounted) return;

      if (response['success'] != true || response['data'] == null) {
        Toast.show(
          context,
          response['message']?.toString() ?? 'Barcode tidak valid',
          isError: true,
        );
        return;
      }

      final data = Map<String, dynamic>.from(response['data']);
      final sku = data['sku']?.toString() ?? '';
      final color = data['color']?.toString() ?? '';
      final size = data['size']?.toString() ?? '';
      final itemName = data['item_name']?.toString() ?? '-';

      if (!_isSequenceUnique(sku, sequence)) {
        Toast.show(
          context,
          'Sequence $sequence sudah pernah di-scan untuk $sku',
          isError: true,
        );
        return;
      }

      final requiredQty = _requiredQtyForKey(sku, color, size);
      final scannedQty = _scannedQtyForKey(sku, color, size);

      if (requiredQty == 0) {
        Toast.show(
          context,
          'Produk tidak ditemukan di order ini',
          isError: true,
        );
        return;
      }

      if (scannedQty >= requiredQty) {
        Toast.show(
          context,
          'Qty maksimum untuk $sku sudah tercapai ($requiredQty)',
          isError: true,
        );
        return;
      }

      setState(() {
        _scannedBarcodes.add(code);
        _scannedItems.add({
          'sku': sku,
          'color': color,
          'size': size,
          'item_name': itemName,
          'sequence': sequence,
          'barcode': code,
          'scanned_at': DateTime.now().toIso8601String(),
        });
      });

      Toast.show(context, '$itemName berhasil di-scan');
      _tabController?.animateTo(1);
    } finally {
      _isProcessingScan = false;
    }
  }

  Future<void> _approveOrder() async {
    if (_selectedOrderId == null) return;

    if (_orderItems.isEmpty) {
      Toast.show(
        context,
        'Order tidak memiliki item untuk dicek',
        isError: true,
      );
      return;
    }

    if (_scannedItems.length != _orderItems.length) {
      Toast.show(
        context,
        'Scan belum lengkap (${_scannedItems.length}/${_orderItems.length})',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final response = await CheckerService.approveOrderWithScans(
        _selectedOrderId!,
        List<String>.from(_scannedBarcodes),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Toast.show(context, 'Order berhasil di-approve');
        _backToListAndRefresh();
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Gagal approve order';
          _isSubmitting = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isSubmitting = false;
      });
    }
  }

  void _backToListAndRefresh() {
    _scannerController?.dispose();
    _scannerController = null;
    // Reset tab to first tab instead of nullifying controller
    _tabController?.index = 0;

    setState(() {
      _selectedOrder = null;
      _selectedOrderId = null;
      _orderItems = [];
      _scannedItems.clear();
      _scannedBarcodes.clear();
      _isSubmitting = false;
      _torchEnabled = false;
    });

    _loadAssignedOrders();
  }

  // ─────────────────────────── BUILD ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'ORDER CHECKER',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(onMenuSelected: _handleMenuSelection),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedOrderId == null
            ? _buildOrderListView()
            : _buildCheckingView(),
      ),
    );
  }

  // ─────────────────────── ORDER LIST ───────────────────────────

  Widget _buildOrderListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 10),
          if (_errorMessage.isNotEmpty) _buildErrorBanner(),
          _buildOrderListCard(),
          const SizedBox(height: 8),
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatChip(
          label: 'Assigned',
          value: _assignedCount.toString(),
          valueColor: null,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          label: 'Today checked',
          value: _todayCheckedCount.toString(),
          valueColor: null,
        ),
        const SizedBox(width: 8),
        _buildStatChip(
          label: 'Pending',
          value: _pendingCount.toString(),
          valueColor: _pendingCount > 0 ? const Color(0xFF854F0B) : null,
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        _errorMessage,
        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
      ),
    );
  }

  Widget _buildOrderListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(
                  'ASSIGNED TO YOU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _loadAssignedOrders,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F0FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 12,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_assignedOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(
                'No orders assigned right now.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          ...List.generate(_assignedOrders.length, (i) {
            final order = Map<String, dynamic>.from(_assignedOrders[i]);
            return _buildOrderListItem(
              order,
              isLast: i == _assignedOrders.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(
    Map<String, dynamic> order, {
    bool isLast = false,
  }) {
    final orderSn = order['order_sn']?.toString() ?? '-';
    final awbCode = order['awb_code']?.toString() ?? '-';
    final customerName = order['customer_name']?.toString() ?? '-';
    final itemCount = (order['item_count'] ?? 0).toString();
    final marketplaceName = order['marketplace']?['name']?.toString() ?? '-';

    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        InkWell(
          onTap: () => _openOrderForChecking(order),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F0FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderSn,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'AWB: $awbCode · $customerName',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildBadge(
                            marketplaceName,
                            bg: const Color(0xFFFAEEDA),
                            fg: const Color(0xFF854F0B),
                          ),
                          const SizedBox(width: 6),
                          _buildBadge(
                            '$itemCount items',
                            bg: const Color(0xFFE6F1FB),
                            fg: const Color(0xFF185FA5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadAssignedOrders();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Prev', style: TextStyle(fontSize: 13)),
          ),
          Text(
            'Page $_currentPage / $_totalPages',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          OutlinedButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadAssignedOrders();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Next', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── CHECKING VIEW ────────────────────────

  Widget _buildCheckingView() {
    final order = _selectedOrder ?? <String, dynamic>{};
    final isFullScanMet =
        _orderItems.isNotEmpty && _scannedItems.length == _orderItems.length;
    final remaining = _orderItems.length - _scannedItems.length;

    return Column(
      children: [
        // Order header card
        _buildCheckingHeader(order, isFullScanMet, remaining),

        // Tabs + content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildScanTab(), _buildScannedListTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Approve button
        _buildApproveButton(isFullScanMet),
      ],
    );
  }

  Widget _buildCheckingHeader(
    Map<String, dynamic> order,
    bool isComplete,
    int remaining,
  ) {
    final progress = _orderItems.isEmpty
        ? 0.0
        : (_scannedItems.length / _orderItems.length).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['order_sn']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${order['customer_name'] ?? '-'} · ${order['marketplace']?['name'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _backToListAndRefresh,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: const Text('Back', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _showOrderDetailsDialog(order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isComplete
                ? Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All items scanned — ${_scannedItems.length} / ${_orderItems.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Ready to approve',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF558B2F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scanned items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${_scannedItems.length} / ${_orderItems.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFDCEDC8),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF558B2F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$remaining more item${remaining == 1 ? '' : 's'} to scan',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF558B2F),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.blue.shade700,
      unselectedLabelColor: Colors.grey.shade500,
      indicatorColor: Colors.blue.shade700,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabs: [
        const Tab(icon: Icon(Icons.qr_code_scanner, size: 18), text: 'Scan'),
        Tab(
          icon: const Icon(Icons.checklist, size: 18),
          text: 'Scanned (${_scannedItems.length})',
        ),
      ],
    );
  }

  Widget _buildScanTab() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcodeDetect,
          ),
        ),
        // Corner brackets overlay
        Center(child: SizedBox(width: 200, height: 200)),
        // Bottom controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildScannerControl(
                icon: _torchEnabled ? Icons.flash_on : Icons.flash_off,
                label: 'Flash',
                onTap: _toggleTorch,
                active: _torchEnabled,
              ),
              const SizedBox(width: 32),
              _buildScannerControl(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                onTap: _flipCamera,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: active ? Colors.amber.shade300 : Colors.white70,
        size: 48,
      ),
    );
  }

  Widget _buildScannedListTab() {
    if (_scannedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              'No items scanned yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _scannedItems.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final item = _scannedItems[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3DE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF3B6D11),
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['item_name']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['sku']} · ${item['color']} · ${item['size']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1FB),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'SQ-${item['sequence']}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF185FA5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApproveButton(bool isFullScanMet) {
    final canApprove = !_isSubmitting && isFullScanMet;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            onPressed: canApprove ? _approveOrder : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canApprove
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade200,
              foregroundColor: canApprove ? Colors.white : Colors.grey.shade400,
              disabledBackgroundColor: Colors.grey.shade200,
              disabledForegroundColor: Colors.grey.shade400,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (canApprove) ...[
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Approve order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Approve order — ${_scannedItems.length} of ${_orderItems.length} scanned',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    final numeric = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '0') ?? 0;
    final formatted = numeric.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return 'Rp $formatted';
  }

  Future<void> _showOrderDetailsDialog(Map<String, dynamic> order) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.blue.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Order details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDialogSection(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Order information',
                          rows: [
                            _DialogRow(
                              'Order SN',
                              order['order_sn']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'AWB Code',
                              order['awb_code']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Store',
                              order['online_store']?['name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Marketplace',
                              order['marketplace']?['name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Item count',
                              (order['item_count'] ?? 0).toString(),
                            ),
                            _DialogRow(
                              'Unique items',
                              (order['unique_item_count'] ?? 0).toString(),
                            ),
                            _DialogRow(
                              'Total price',
                              _formatCurrency(order['total_price']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDialogSection(
                          icon: Icons.person_outline,
                          title: 'Customer information',
                          rows: [
                            _DialogRow(
                              'Customer',
                              order['customer_name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Phone',
                              order['customer_phone']?.toString() ?? '-',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDialogSection(
                          icon: Icons.location_on_outlined,
                          title: 'Shipping address',
                          rows: [],
                          customChild: Text(
                            order['customer_address']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSection({
    required IconData icon,
    required String title,
    required List<_DialogRow> rows,
    Widget? customChild,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (customChild != null) customChild,
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.value.trim().isEmpty ? '-' : r.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
