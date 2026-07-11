part of '../checker_screen.dart';

extension _CheckerScreenListViewExtension on _CheckerScreenState {
  Widget _buildOrderListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 10),
          if (_errorMessage.isNotEmpty) _buildErrorBanner(),
          _buildSearchFilterCard(),
          const SizedBox(height: 10),
          _buildOrderListCard(),
          const SizedBox(height: 8),
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchFilterCard() {
    return CheckerSearchFilterCard(
      searchController: _searchController,
      searchQuery: _searchQuery,
      onSearchChanged: (value) => _updateState(() => _searchQuery = value),
      onSearchSubmitted: () {
        _updateState(() => _currentPage = 1);
        _performSearch();
      },
      onClearSearch: () {
        _searchController.clear();
        _updateState(() {
          _searchQuery = '';
          _currentPage = 1;
        });
        if (_selectedMarketplaceId == null) {
          _loadAssignedOrders();
        } else {
          _performSearch();
        }
      },
      availableMarketplaces: _availableMarketplaces,
      selectedMarketplaceId: _selectedMarketplaceId,
      onMarketplaceChanged: (value) {
        _updateState(() {
          _selectedMarketplaceId = value;
          _currentPage = 1;
        });
        _performSearch();
      },
      serialController: _serialInputController,
      onSerialSubmitted: _openOrderWithSerial,
      onScanQr: _scanSerialAndOpenOrder,
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        CheckerStatChip(
          label: 'Assigned',
          value: _assignedCount.toString(),
          valueColor: null,
        ),
        const SizedBox(width: 8),
        CheckerStatChip(
          label: 'Pending',
          value: _pendingCount.toString(),
          valueColor: _pendingCount > 0 ? const Color(0xFF854F0B) : null,
        ),
      ],
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
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                  onTap: _refreshOrdersForCurrentQuery,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child: AnimatedOpacity(
              opacity: _isListLoading ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ),
          if (_getFilteredOrders().isEmpty && !_isListLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(
                'No orders assigned right now.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          ..._buildFilteredOrdersList(),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredOrdersList() {
    final filteredOrders = _getFilteredOrders();
    return List.generate(filteredOrders.length, (i) {
      final order = Map<String, dynamic>.from(filteredOrders[i]);
      return _buildOrderListItem(order, isLast: i == filteredOrders.length - 1);
    });
  }

  Widget _buildOrderListItem(
    Map<String, dynamic> order, {
    bool isLast = false,
  }) {
    final orderSn = order['order_sn']?.toString() ?? '-';
    final awbCodeRaw = order['awb_code']?.toString().trim() ?? '';
    final awbCode = awbCodeRaw.isEmpty ? 'n/a' : awbCodeRaw;
    final customerName = order['customer_name']?.toString() ?? '-';
    final itemCount = (order['item_count'] ?? 0).toString();
    final marketplaceName = order['marketplace']?['name']?.toString() ?? '-';

    return CheckerOrderListItemTile(
      orderSn: orderSn,
      awbCode: awbCode,
      customerName: customerName,
      itemCountText: '$itemCount items',
      marketplaceName: marketplaceName,
      onTap: () => _openOrderForChecking(order),
    );
  }

  Widget _buildPagination() {
    return CheckerPaginationBar(
      currentPage: _currentPage,
      totalPages: _totalPages,
      onPrev: _currentPage > 1
          ? () {
              _updateState(() => _currentPage--);
              if (_searchQuery.isNotEmpty ||
                  (_selectedMarketplaceId != null &&
                      _selectedMarketplaceId!.isNotEmpty)) {
                _performSearch();
              } else {
                _loadAssignedOrders();
              }
            }
          : null,
      onNext: _currentPage < _totalPages
          ? () {
              _updateState(() => _currentPage++);
              if (_searchQuery.isNotEmpty ||
                  (_selectedMarketplaceId != null &&
                      _selectedMarketplaceId!.isNotEmpty)) {
                _performSearch();
              } else {
                _loadAssignedOrders();
              }
            }
          : null,
    );
  }
}
