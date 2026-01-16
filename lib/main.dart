import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'state/auth_provider.dart';
// import 'state/dashboard_provider.dart';
import 'utils/secure_storage.dart';
import 'utils/auth_event_bus.dart';
import 'api/http_client.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); // Load .env file
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialToken;
  bool _checkingToken = true;
  StreamSubscription? _tokenExpiredSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadToken();
    _setupTokenExpiredListener();
  }
  
  void _setupTokenExpiredListener() {
    _tokenExpiredSubscription = AuthEventBus.onTokenExpired.listen((_) {
      print('🔒 Token expired event received - redirecting to login');
      // Navigate to login screen and clear all previous routes
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    });
  }
  
  @override
  void dispose() {
    _tokenExpiredSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await AppStorage.getAccessToken();
    
    // CRITICAL: Set token to ApiClient if it exists
    if (token != null) {
      ApiClient.setToken(token);
      print('✅ Token loaded and set to API client');
    } else {
      print('⚠️ No token found in storage');
    }
    
    setState(() {
      _initialToken = token;
      _checkingToken = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingToken) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'PS Mobile App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: _initialToken != null ? DashboardScreen() : LoginScreen(),
      ),
    );
  }
}
