import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ps_mobileapp_main/components/loading.dart';
import 'package:ps_mobileapp_main/components/toast.dart';
import 'package:ps_mobileapp_main/components/app_drawer.dart';
import 'package:ps_mobileapp_main/screens/login_screen.dart';
import 'package:ps_mobileapp_main/screens/outbound_screen.dart';
import 'package:ps_mobileapp_main/screens/inbound_screen.dart';
import 'package:ps_mobileapp_main/screens/reject_screen.dart';
import 'package:ps_mobileapp_main/screens/order_screen.dart';
import 'package:ps_mobileapp_main/state/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreen();
}

class _DashboardScreen extends State<DashboardScreen> {
  bool _loading = false;

  Future<void> _handleLogout() async {
    setState(() {
      _loading = true;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.logout();

    setState(() => _loading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      if (mounted) Toast.show(context, "Logout gagal. Silakan coba lagi.");
    }
  }

  void _handleMenuSelection(String menu) {
    switch (menu) {
      case 'dashboard':
        // Already on dashboard screen
        break;
      case 'order':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderScreen()),
        );
        break;
      case 'order_saya':
        // TODO: Navigate to order saya screen
        break;
      case 'outbound':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OutboundScreen()),
        );
        break;
      case 'inbound':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InboundScreen()),
        );
        break;
      case 'reject':
        Navigator.push(
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
        _handleLogout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loading(
      isLoading: _loading,
      child: Scaffold(
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
          onMenuSelected: _handleMenuSelection,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Welcome to the Dashboard!", style: TextStyle(fontSize: 24)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  textStyle: TextStyle(fontSize: 16),
                ),
                child: Text("Logout"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
