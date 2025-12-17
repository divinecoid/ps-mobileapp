import 'package:flutter/material.dart';

class AppDrawer extends StatefulWidget {
  final String? staffId;
  final Function(String)? onMenuSelected;

  const AppDrawer({
    super.key,
    this.staffId,
    this.onMenuSelected,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _isScanExpanded = true;

  void _handleMenuTap(String menuName) {
    // Close drawer first
    Navigator.pop(context);
    // Then handle menu selection after drawer is closed
    // Use Future.microtask to ensure it runs after the current frame
    Future.microtask(() {
      if (widget.onMenuSelected != null) {
        widget.onMenuSelected!(menuName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header dengan PREPARIST APP
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Text(
                  'PREPARIST APP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // ID Staff Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID Staff',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.staffId ?? 'Staff-001',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'N',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
              children: [
                // Dashboard
                _buildMenuCard(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () => _handleMenuTap('dashboard'),
                ),

                SizedBox(height: 8),

                // Order
                _buildMenuCard(
                  icon: Icons.shopping_cart,
                  title: 'Order',
                  onTap: () => _handleMenuTap('order'),
                ),

                SizedBox(height: 8),

                // Order Saya
                _buildMenuCard(
                  icon: Icons.list_alt,
                  title: 'Order Saya',
                  onTap: () => _handleMenuTap('order_saya'),
                ),

                SizedBox(height: 8),

                // Scan Menu (Expandable)
                _buildExpandableScanMenu(),

                SizedBox(height: 8),

                // Daily Personal Statistics
                _buildMenuCard(
                  icon: Icons.bar_chart,
                  title: 'Daily Personal Statistics',
                  onTap: () => _handleMenuTap('daily_statistics'),
                ),

                SizedBox(height: 8),

                // Stock Opname
                _buildMenuCard(
                  icon: Icons.inventory_2,
                  title: 'Stock Opname',
                  onTap: () => _handleMenuTap('stock_opname'),
                ),

                SizedBox(height: 8),

                SizedBox(height: 8),

                // Mutasi
                _buildMenuCard(
                  icon: Icons.swap_horiz,
                  title: 'Mutasi',
                  onTap: () => _handleMenuTap('mutasi'),
                ),

                SizedBox(height: 8),

                // Log Out
                _buildMenuCard(
                  icon: Icons.logout,
                  title: 'Log Out',
                  onTap: () => _handleMenuTap('logout'),
                  isLogout: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableScanMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Scan Header (Clickable)
          InkWell(
            onTap: () {
              setState(() {
                _isScanExpanded = !_isScanExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  Icon(
                    _isScanExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Submenu Items (Animated)
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            height: _isScanExpanded ? null : 0,
            child: _isScanExpanded
                ? Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Divider(height: 1),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: _buildScanSubmenuItem(
                            title: 'Outbound',
                            icon: Icons.output,
                            color: Colors.red.shade100,
                            iconColor: Colors.red.shade700,
                            onTap: () => _handleMenuTap('outbound'),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: _buildScanSubmenuItem(
                            title: 'Inbound',
                            icon: Icons.input,
                            color: Colors.blue.shade100,
                            iconColor: Colors.blue.shade700,
                            onTap: () => _handleMenuTap('inbound'),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: _buildScanSubmenuItem(
                            title: 'Reject',
                            icon: Icons.cancel,
                            color: Colors.yellow.shade100,
                            iconColor: Colors.orange.shade600,
                            onTap: () => _handleMenuTap('reject'),
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSubmenuItem({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    // For Reject, use a circular container with white X
    if (title == 'Reject') {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? Colors.red.shade700 : Colors.blue.shade700,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isLogout ? Colors.red.shade700 : Colors.grey[900],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
