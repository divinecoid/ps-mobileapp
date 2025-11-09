import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ps_mobileapp_main/components/loading.dart';
import 'package:ps_mobileapp_main/components/toast.dart';
import 'package:ps_mobileapp_main/screens/login_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Loading(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: Text("Dashboard")),
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
