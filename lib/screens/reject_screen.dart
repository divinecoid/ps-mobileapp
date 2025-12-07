import 'package:flutter/material.dart';
import '../components/app_drawer.dart';
import 'outbound_screen.dart';
import 'inbound_screen.dart';

class RejectScreen extends StatelessWidget {
  const RejectScreen({super.key});

  void _handleMenuSelection(BuildContext context, String menu) {
    switch (menu) {
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
        // Already on reject screen
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
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => _handleMenuSelection(context, menu),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel,
              size: 80,
              color: Colors.orange.shade300,
            ),
            SizedBox(height: 20),
            Text(
              'Reject Screen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Fitur Reject akan segera hadir',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
