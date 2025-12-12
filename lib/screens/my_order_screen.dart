import 'package:flutter/material.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';

class MyOrderScreen extends StatefulWidget {
  const MyOrderScreen({super.key});

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen> {
  // Dummy data orders with items (only assigned orders)
  final List<Map<String, dynamic>> _myOrders = [
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
      'id': '5',
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
  ];

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'order_saya');
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
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(menu),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: Colors.blue.shade700,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Order Saya',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _myOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada order yang di-assign',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _myOrders.length,
                    itemBuilder: (context, index) {
                      final order = _myOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade700, width: 2),
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
          _showOrderDetail(order);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name with Assigned Badge
              Row(
                children: [
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
                          // Unassign order
                          setState(() {
                            _myOrders.removeWhere((o) => o['id'] == order['id']);
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order berhasil di-unassign'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'LEMPAR ORDERAN',
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
}

