import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:provider/provider.dart';

// import 'state/auth_provider.dart';
// import 'state/dashboard_provider.dart';
// import 'utils/secure_storage.dart';
// import 'screens/login_screen.dart';
// import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); // Load .env file before app starts
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialToken;

  @override
  void initState() {
    super.initState();
    _loadStoredToken();
  }

  Future<void> _loadStoredToken() async {
    final token = await AppStorage.getAccessToken();
    setState(() {
      _initialToken = token; // If null → user goes to login
    });
  }

  @override
  Widget build(BuildContext context) {
    // While loading token, show splash-like loader
    if (_initialToken == null) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => AuthProvider()),
    //     ChangeNotifierProvider(create: (_) => DashboardProvider()),
    //   ],
    //   child: MaterialApp(
    //     debugShowCheckedModeBanner: false,
    //     title: 'Order Management App',
    //     theme: ThemeData(primarySwatch: Colors.blue),
    //     home: _initialToken != null ? DashboardScreen() : LoginScreen(),
    //   ),
    // );
  }
}
