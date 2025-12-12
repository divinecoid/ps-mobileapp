import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/order_screen.dart';
import '../screens/my_order_screen.dart';
import '../screens/outbound_screen.dart';
import '../screens/inbound_screen.dart';
import '../screens/reject_screen.dart';
import '../screens/login_screen.dart';
import '../state/auth_provider.dart';
import 'package:provider/provider.dart';
import '../components/toast.dart';

class NavigationHelper {
  /// Handle menu selection from app drawer
  /// Returns true if navigation was handled, false otherwise
  /// [usePush] - if true, uses Navigator.push instead of pushReplacement (for dashboard)
  static bool handleMenuSelection(BuildContext context, String menu, {String? currentScreen, bool usePush = false}) {
    switch (menu) {
      case 'dashboard':
        if (currentScreen != 'dashboard') {
          if (usePush) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DashboardScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => DashboardScreen()),
            );
          }
        }
        return true;

      case 'order':
        if (currentScreen != 'order') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OrderScreen()),
          );
        }
        return true;

      case 'order_saya':
        if (currentScreen != 'order_saya') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MyOrderScreen()),
          );
        }
        return true;

      case 'outbound':
        if (currentScreen != 'outbound') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OutboundScreen()),
          );
        }
        return true;

      case 'inbound':
        if (currentScreen != 'inbound') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => InboundScreen()),
          );
        }
        return true;

      case 'reject':
        if (currentScreen != 'reject') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RejectScreen()),
          );
        }
        return true;

      case 'daily_statistics':
        // TODO: Navigate to daily statistics screen
        return true;

      case 'stock_opname':
        // TODO: Navigate to stock opname screen
        return true;

      case 'mutasi':
        // TODO: Navigate to mutasi screen
        return true;

      case 'logout':
        _handleLogout(context);
        return true;

      default:
        return false;
    }
  }

  /// Handle logout action
  static Future<void> _handleLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.logout();

    if (success && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } else {
      if (context.mounted) {
        Toast.show(context, "Logout gagal. Silakan coba lagi.");
      }
    }
  }
}

