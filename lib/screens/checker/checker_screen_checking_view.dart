part of '../checker_screen.dart';

extension _CheckerScreenCheckingViewExtension on _CheckerScreenState {
  Widget _buildCheckingView() {
    final order = _selectedOrder ?? <String, dynamic>{};
    final isFullScanMet =
        _orderItems.isNotEmpty && _scannedItems.length == _orderItems.length;
    final remaining = _orderItems.length - _scannedItems.length;

    return Column(
      children: [
        _buildCheckingHeader(order, isFullScanMet, remaining),
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
                      children: [_buildScanTab(), _buildOrderItemsTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildApproveBar(isFullScanMet),
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

    final orderSn = order['order_sn']?.toString() ?? '-';
    final customerAndMarketplace =
        '${order['customer_name'] ?? '-'} · ${order['marketplace']?['name'] ?? '-'}';

    return CheckerCheckingHeader(
      orderSn: orderSn,
      customerAndMarketplace: customerAndMarketplace,
      onBack: _backToListAndRefresh,
      onDetails: () => _showOrderDetailsDialog(order),
      isComplete: isComplete,
      scannedCount: _scannedItems.length,
      totalCount: _orderItems.length,
      remaining: remaining,
      progress: progress,
    );
  }

  Widget _buildTabBar() {
    return CheckerCheckingTabBar(
      controller: _tabController,
      scannedCount: _scannedItems.length,
      totalCount: _orderItems.length,
    );
  }

  Widget _buildScanTab() {
    return CheckerScanTab(
      controller: _scannerController,
      onDetect: _handleBarcodeDetect,
      torchEnabled: _torchEnabled,
      onToggleTorch: _toggleTorch,
      onFlipCamera: _flipCamera,
    );
  }

  Widget _buildOrderItemsTab() {
    return CheckerOrderItemsTab(
      orderItems: _orderItems,
      scannedItems: _scannedItems,
    );
  }

  Widget _buildApproveBar(bool isFullScanMet) {
    return CheckerApproveBar(
      isSubmitting: _isSubmitting,
      isFullScanMet: isFullScanMet,
      scannedCount: _scannedItems.length,
      totalCount: _orderItems.length,
      onApprove: _approveOrder,
    );
  }
}
