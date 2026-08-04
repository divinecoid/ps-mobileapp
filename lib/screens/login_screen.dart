import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_provider.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Basic validation
    if (_usernameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Username and Password cannot be empty";
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _loading = false);
    }

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = "Invalid username or password";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Background Gradient (Bright & Clean)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8FAFC), // Slate 50
                  Color(0xFFF1F5F9), // Slate 100
                  Color(0xFFE2E8F0), // Slate 200
                ],
              ),
            ),
          ),

          // 2. Decorative Glowing Spheres (Soft & Bright)
          // Top Left Sphere
          Positioned(
            top: -screenSize.height * 0.1,
            left: -screenSize.width * 0.15,
            child: Container(
              width: screenSize.width * 0.7,
              height: screenSize.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1F3B82F6), // Very light Blue Glow
                    Color(0x003B82F6),
                  ],
                ),
              ),
            ),
          ),
          
          // Middle Right Sphere
          Positioned(
            top: screenSize.height * 0.3,
            right: -screenSize.width * 0.25,
            child: Container(
              width: screenSize.width * 0.8,
              height: screenSize.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1F8B5CF6), // Very light Purple Glow
                    Color(0x008B5CF6),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Left Sphere
          Positioned(
            bottom: -screenSize.height * 0.05,
            left: -screenSize.width * 0.1,
            child: Container(
              width: screenSize.width * 0.6,
              height: screenSize.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1F06B6D4), // Very light Cyan Glow
                    Color(0x0006B6D4),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    return Opacity(
                      opacity: animValue,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1.0 - animValue)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Elegant App Logo Section
                      Center(
                        child: Container(
                          height: 90,
                          width: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade100,
                                Colors.blue.shade50.withOpacity(0.5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.asset(
                                'assets/images/icon.png',
                                height: 56,
                                width: 56,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback beautiful iconic graphic if image not loaded
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.blue.shade500, Colors.indigo.shade600],
                                      ),
                                    ),
                                    padding: EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // App Name & Welcome text
                      Text(
                        "PLAINSTORE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Color(0xFF1E293B), // Dark Slate
                          shadows: [
                            Shadow(
                              color: Colors.blue.shade200.withOpacity(0.3),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            )
                          ]
                        ),
                      ),
                      
                      SizedBox(height: 6),
                      
                      Text(
                        "Enter credentials to access mobile dashboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B), // Slate 500
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      SizedBox(height: 36),

                      // Clean Light Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Color(0xFFE2E8F0), // Slate 200
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Sleek Error Message Box
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  margin: EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red.shade700,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Username Input Field
                              _buildTextField(
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                labelText: "Username",
                                hintText: "Enter your username",
                                prefixIcon: Icons.person_outline_rounded,
                              ),

                              SizedBox(height: 20),

                              // Password Input Field
                              _buildTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                labelText: "Password",
                                hintText: "Enter your password",
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _passwordFocusNode.hasFocus
                                        ? Colors.blue.shade600
                                        : Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),

                              SizedBox(height: 12),

                              // Sleek Forgot Password placeholder
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Optional placeholder feedback
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Please contact system administrator to reset password."),
                                        backgroundColor: Colors.indigo.shade800,
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 28),

                              // Elegant Morphing Gradient Login Button
                              Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: _loading
                                        ? [Colors.blue.shade600.withOpacity(0.7), Colors.indigo.shade700.withOpacity(0.7)]
                                        : [Colors.blue.shade600, Colors.indigo.shade700],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: _loading
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.blue.shade500.withOpacity(0.3),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _loading ? null : _handleLogin,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Center(
                                      child: _loading
                                          ? SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              "LOG IN",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 40),
                      
                      // Footer Version Text
                      Text(
                        "PS MOBILE v0.0.1",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8), // Slate 400
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Beautiful Reusable TextField Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Label Text
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            labelText,
            style: TextStyle(
              color: isFocused ? Colors.blue.shade600 : Color(0xFF64748B), // Slate 500
              fontSize: 12,
              fontWeight: isFocused ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        
        // Input Decoration wrapper
        AnimatedContainer(
          duration: Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isFocused ? Colors.white : Color(0xFFF8FAFC), // Slate 50
            border: Border.all(
              color: isFocused 
                  ? Colors.blue.shade500 
                  : Color(0xFFE2E8F0), // Slate 200
              width: isFocused ? 1.8 : 1.0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Colors.blue.shade500.withOpacity(0.08),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            style: TextStyle(
              color: Color(0xFF1E293B), // Slate 800
              fontSize: 15,
            ),
            cursorColor: Colors.blue.shade600,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Color(0xFF94A3B8), // Slate 400
                fontSize: 14,
              ),
              prefixIcon: Icon(
                prefixIcon,
                color: isFocused ? Colors.blue.shade600 : Color(0xFF94A3B8), // Slate 400
                size: 22,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

