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
    return Container(
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
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SEARCH & FILTER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      _updateState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search AWB, serial, or customer...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            onPressed: () {
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
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF1565C0),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) {
                    _updateState(() => _currentPage = 1);
                    _performSearch();
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _updateState(() => _currentPage = 1);
                  _performSearch();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_availableMarketplaces.isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        value: _selectedMarketplaceId,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        hint: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Marketplaces',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        selectedItemBuilder: (_) => [
                          _buildDropdownSelectedItem('All Marketplaces'),
                          ..._availableMarketplaces.map(
                            (m) => _buildDropdownSelectedItem(
                              m['name']?.toString() ?? '-',
                            ),
                          ),
                        ],
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Marketplaces'),
                          ),
                          ..._availableMarketplaces.map(
                            (m) => DropdownMenuItem<String>(
                              value: m['id']?.toString(),
                              child: Text(m['name']?.toString() ?? '-'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _updateState(() {
                            _selectedMarketplaceId = value;
                            _currentPage = 1;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _scanSerialAndOpenOrder,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Scan QR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSelectedItem(String name) {
    return Row(
      children: [
        Icon(Icons.storefront_outlined, size: 15, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                  onTap: _loadAssignedOrders,
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
          if (_getFilteredOrders().isEmpty)
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
}
