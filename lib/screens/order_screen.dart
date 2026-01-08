import 'package:flutter/material.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';
import '../api/order_service.dart';
import '../components/toast.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  /// Track orders you assigned
  final Set<String> _assignedOrders = {};

  bool _isMultiSelectMode = false;
  final Set<String> _selectedOrders = {};

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await OrderService.getOrders();

      // MAPPING SESUAI BACKEND
      final mappedOrders = orders.map((o) {
        return {
          'id': o['id'].toString(),
          'awbCode': o['awb_code'],
          'readAt': o['read_at'],
          'preparedAt': o['prepared_at'],
          'prepareDuration': o['prepare_duration'],
          'readToShipAt': o['readtoship_at'],
          'readToShipMarketplace': o['readtoship_marketplace'],
          'onlineStoreId': o['online_store_id'],
          'itemCount': o['item_count'],
          'uniqueItemCount': o['unique_item_count'],
          'status': o['status'],
          'totalWeight': o['total_weight'],
          'totalPrice': o['total_price'],
          'totalShipping': o['total_shipping'],
          'totalAmount': o['total_amount'],
          'preparistUserId': o['preparist_user_id'],
          'customerName': o['customer_name'],
          'customerPhone': o['customer_phone'],
          'customerAddress': o['customer_address'],
        };
      }).toList();

      print("Mapped: $mappedOrders");

      setState(() {
        _orders = mappedOrders;
        _isLoading = false;
      });
    } catch (e) {
      print("Fetch Error: $e");
      setState(() {
        _errorMessage = "Gagal memuat order: $e";
        _isLoading = false;
      });
      Toast.show(context, _errorMessage!);
    }
  }

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'order');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text("PREPARIST APP",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              onPressed: _selectedOrders.isNotEmpty
                  ? _assignMultipleOrders
                  : null,
              icon: Icon(Icons.person_add, color: Colors.white),
            ),
          if (_isMultiSelectMode)
            IconButton(
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedOrders.clear();
                });
              },
              icon: Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
      drawer: AppDrawer(onMenuSelected: _handleMenuSelection),
      body: Column(
        children: [
          _buildTopButtons(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTopButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.filter_list, color: Colors.white),
            label: Text("Filter", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
          ),
          SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _fetchOrders,
            icon: Icon(Icons.refresh, color: Colors.white),
            label: Text("Refresh", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text("Memuat order..."),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.red),
            SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center),
            SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchOrders, child: Text("Coba Lagi")),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 50, color: Colors.grey),
            SizedBox(height: 12),
            Text("Tidak ada order"),
            ElevatedButton(onPressed: _fetchOrders, child: Text("Refresh")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _orders.length,
        itemBuilder: (context, i) =>
            _buildOrderCard(_orders[i]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = order['id'];
    final isAssigned = _assignedOrders.contains(id);
    final isSelected = _selectedOrders.contains(id);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.blue.shade700, width: 3)
            : isAssigned
                ? Border.all(color: Colors.blue.shade700, width: 2)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              isSelected
                  ? _selectedOrders.remove(id)
                  : _selectedOrders.add(id);
            });
          } else {
            _showOrderDetail(order);
          }
        },
        onLongPress: () {
          setState(() {
            _isMultiSelectMode = true;
            _selectedOrders.add(id);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              Row(
                children: [
                  if (_isMultiSelectMode)
                    Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isSelected ? Colors.blue.shade700 : Colors.grey,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      order['customerName'] ?? '-',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isAssigned)
                    _badge("ASSIGNED", Colors.blue.shade700),
                ],
              ),
              SizedBox(height: 12),

              _iconText(Icons.location_on, order['customerAddress']),
              SizedBox(height: 8),

              _iconText(Icons.receipt, "AWB: ${order['awbCode']}"),
              SizedBox(height: 8),

              _iconText(Icons.shopping_bag,
                  "Items: ${order['itemCount']} (${order['uniqueItemCount']} unik)"),
              SizedBox(height: 8),

              _iconText(Icons.info, "Status: ${order['status']}"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    final id = order['id'];
    final isAssigned = _assignedOrders.contains(id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDetailSheet(order, isAssigned),
    );
  }

  Widget _buildDetailSheet(Map<String, dynamic> order, bool isAssigned) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text("Detail Order",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                )
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _detailCard(order),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _actionButtons(order['id'], isAssigned),
        ],
      ),
    );
  }

  Widget _detailCard(Map<String, dynamic> o) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o['customerName'],
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          _iconText(Icons.location_on, o['customerAddress']),
          SizedBox(height: 8),
          _iconText(Icons.phone, o['customerPhone']),
          SizedBox(height: 8),
          _iconText(Icons.receipt, "AWB: ${o['awbCode']}"),
          SizedBox(height: 8),
          _iconText(Icons.shopping_bag,
              "Items: ${o['itemCount']} (${o['uniqueItemCount']} unik)"),
          SizedBox(height: 8),
          _iconText(Icons.info, "Status: ${o['status']}"),
        ],
      ),
    );
  }

  Widget _actionButtons(String id, bool isAssigned) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                child: Text("PRINT"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300]),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  isAssigned ? _unassignOrder(id) : _assignOrder(id);
                  Navigator.pop(context);
                },
                child: Text(
                  isAssigned ? "LEMPAR ORDERAN" : "AMBIL ORDERAN",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isAssigned ? Colors.orange.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ASSIGN LOGIC
  void _assignOrder(String id) {
    setState(() => _assignedOrders.add(id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Order di-assign"), backgroundColor: Colors.green),
    );
  }

  void _unassignOrder(String id) {
    setState(() => _assignedOrders.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Order dilepas"), backgroundColor: Colors.orange),
    );
  }

  void _assignMultipleOrders() {
    final count = _selectedOrders.length;
    setState(() {
      _assignedOrders.addAll(_selectedOrders);
      _selectedOrders.clear();
      _isMultiSelectMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$count order berhasil di-assign"),
        backgroundColor: Colors.green,
      ),
    );
  }
}
