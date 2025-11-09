import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'state/auth_provider.dart';
// import 'state/dashboard_provider.dart';
import 'utils/secure_storage.dart';
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

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final token = await AppStorage.getAccessToken();
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
        debugShowCheckedModeBanner: false,
        title: 'PS Mobile App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: _initialToken != null ? DashboardScreen() : LoginScreen(),
      ),
    );
  }
}
