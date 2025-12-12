import 'package:flutter/material.dart';
import '../components/app_drawer.dart';
import 'dashboard_screen.dart';
import 'outbound_screen.dart';
import 'inbound_screen.dart';
import 'reject_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  // Track assigned orders (using customer name as ID for now)
  final Set<String> _assignedOrders = {};
  
  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedOrders = {};

  // Dummy data orders with items
  final List<Map<String, dynamic>> _orders = [
    {
      'id': '1',
      'customerName': 'Randy Khengdy',
      'address': 'Jl. Kelapa Gading Raya No.1',
      'totalItems': 3,
      'deliveryType': 'GRAB - Instan',
      'notes': 'Butuh cepat !',
      'items': [
        {'name': 'POLO BLACK XXL CUSTOM', 'qty': 1},
        {'name': 'POLO WHITE XXL', 'qty': 2},
      ],
    },
    {
      'id': '2',
      'customerName': 'William',
      'address': 'Apt. Sudirman Mansion',
      'totalItems': 7,
      'deliveryType': 'SiCepat - Sameday Service',
      'notes': 'Kirim Bang',
      'items': [
        {'name': 'T-Shirt Red M', 'qty': 3},
        {'name': 'T-Shirt Blue L', 'qty': 4},
      ],
    },
    {
      'id': '3',
      'customerName': 'Sarah Wijaya',
      'address': 'Jl. Thamrin No. 15, Jakarta Pusat',
      'totalItems': 5,
      'deliveryType': 'JNE - REG',
      'notes': 'Hati-hati barang mudah pecah',
      'items': [
        {'name': 'Kemeja Putih L', 'qty': 2},
        {'name': 'Kemeja Biru M', 'qty': 2},
        {'name': 'Kemeja Hitam XL', 'qty': 1},
      ],
    },
    {
      'id': '4',
      'customerName': 'Budi Santoso',
      'address': 'Jl. Gatot Subroto No. 88, Jakarta Selatan',
      'totalItems': 4,
      'deliveryType': 'GoSend - Same Day',
      'notes': null,
      'items': [
        {'name': 'Jaket Hoodie Hitam XL', 'qty': 2},
        {'name': 'Jaket Hoodie Abu-abu L', 'qty': 2},
      ],
    },
    {
      'id': '5',
      'customerName': 'Lisa Permata',
      'address': 'Komplek Permata Hijau Blok A No. 12',
      'totalItems': 6,
      'deliveryType': 'J&T Express - Ekspres',
      'notes': 'Tolong dibungkus rapi',
      'items': [
        {'name': 'Dress Merah M', 'qty': 1},
        {'name': 'Dress Biru S', 'qty': 2},
        {'name': 'Dress Putih L', 'qty': 3},
      ],
    },
    {
      'id': '6',
      'customerName': 'Ahmad Fauzi',
      'address': 'Jl. Sudirman Kav. 52-53, Jakarta',
      'totalItems': 8,
      'deliveryType': 'Pos Indonesia - Kilat Khusus',
      'notes': 'Urgent!',
      'items': [
        {'name': 'Celana Jeans Hitam 32', 'qty': 3},
        {'name': 'Celana Jeans Biru 34', 'qty': 2},
        {'name': 'Celana Chino Coklat 33', 'qty': 3},
      ],
    },
    {
      'id': '7',
      'customerName': 'Dewi Sari',
      'address': 'Jl. Kemang Raya No. 45, Jakarta Selatan',
      'totalItems': 3,
      'deliveryType': 'GRAB - Instan',
      'notes': 'Tolong diantar sebelum jam 5 sore',
      'items': [
        {'name': 'Blouse Putih M', 'qty': 1},
        {'name': 'Blouse Pink L', 'qty': 2},
      ],
    },
  ];

  void _handleMenuSelection(String menu) {
    switch (menu) {
      case 'dashboard':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen()),
        );
        break;
      case 'order':
        // Already on order screen
        break;
      case 'order_saya':
        // TODO: Navigate to order saya screen
        break;
      case 'outbound':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OutboundScreen()),
        );
        break;
      case 'inbound':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InboundScreen()),
        );
        break;
      case 'reject':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RejectScreen()),
        );
        break;
      case 'daily_statistics':
        // TODO: Navigate to daily statistics screen
        break;
      case 'stock_opname':
        // TODO: Navigate to stock opname screen
        break;
      case 'mutasi':
        // TODO: Navigate to mutasi screen
        break;
      case 'logout':
        // Logout will be handled by parent screen
        Navigator.popUntil(context, (route) => route.isFirst);
        break;
    }
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
        title: Text(
          'PREPARIST APP',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              icon: Icon(Icons.person_add, color: Colors.white),
              onPressed: _selectedOrders.isEmpty
                  ? null
                  : () {
                      _assignMultipleOrders();
                    },
              tooltip: 'Assign to me',
            ),
          if (_isMultiSelectMode)
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedOrders.clear();
                });
              },
              tooltip: 'Cancel selection',
            ),
        ],
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(menu),
      ),
      body: Column(
        children: [
          // Filter Button
          Container(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement filter functionality
                },
                icon: Icon(Icons.filter_list, color: Colors.white),
                label: Text(
                  'Filter',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final isAssigned = _assignedOrders.contains(order['id']);
                final isSelected = _selectedOrders.contains(order['id']);
                return _buildOrderCard(order, isAssigned, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isAssigned, bool isSelected) {
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
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedOrders.remove(order['id']);
              } else {
                _selectedOrders.add(order['id']);
              }
            });
          } else {
            _showOrderDetail(order);
          }
        },
        onLongPress: () {
          setState(() {
            _isMultiSelectMode = true;
            _selectedOrders.add(order['id']);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name with Assigned Badge and Checkbox
              Row(
                children: [
                  if (_isMultiSelectMode)
                    Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade700 : Colors.grey[400]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      order['customerName'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  if (isAssigned && !_isMultiSelectMode)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ASSIGNED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['address'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Total Items
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Total Items: ${order['totalItems']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Delivery Type
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    order['deliveryType'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // Notes
              if (order['notes'] != null && order['notes'].toString().isNotEmpty)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note,
                        size: 18,
                        color: Colors.orange.shade700,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    final isAssigned = _assignedOrders.contains(order['id']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detail Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Divider(),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary Card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['customerName'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.local_shipping, size: 18, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['deliveryType'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (order['notes'] != null && order['notes'].toString().isNotEmpty) ...[
                            SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.note, size: 18, color: Colors.orange.shade700),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order['notes'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange.shade900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Items List Card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 12),
                          ...(order['items'] as List).map<Widget>((item) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['qty']} pc ${item['name']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Container(
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
                      onPressed: () {
                        // TODO: Implement print functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'PRINT',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (isAssigned) {
                          _unassignOrder(order['id']);
                        } else {
                          _assignOrder(order['id']);
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAssigned ? Colors.orange.shade700 : Colors.blue.shade700,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isAssigned ? 'LEMPAR ORDERAN' : 'AMBIL ORDERAN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
    );
  }

  void _assignOrder(String orderId) {
    setState(() {
      _assignedOrders.add(orderId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order berhasil di-assign ke Anda'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _unassignOrder(String orderId) {
    setState(() {
      _assignedOrders.remove(orderId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order berhasil di-unassign'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _assignMultipleOrders() {
    if (_selectedOrders.isEmpty) return;

    final count = _selectedOrders.length;
    
    setState(() {
      _assignedOrders.addAll(_selectedOrders);
      _selectedOrders.clear();
      _isMultiSelectMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count order berhasil di-assign ke Anda'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

