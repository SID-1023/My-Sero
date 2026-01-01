import 'dart:ui';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class SeroLoginPage extends StatefulWidget {
  const SeroLoginPage({super.key});

  @override
  State<SeroLoginPage> createState() => _SeroLoginPageState();
}

class _SeroLoginPageState extends State<SeroLoginPage>
    with SingleTickerProviderStateMixin {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Identity credentials incomplete.");
      return;
    }

    setState(() => _isLoading = true);
    final response = await _authService.login(username, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (response.success) {
        Navigator.pushReplacementNamed(context, '/');
      } else {
        _showError("Signal Interrupted: ${response.error?.message}");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Courier')),
        backgroundColor: const Color(0xFFFF2D55).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          // 1. Dynamic Background Glows
          Positioned(
            top: -150,
            left: -100,
            child: _buildGlow(const Color(0xFF00FF11).withOpacity(0.12), 400),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _buildGlow(const Color(0xFF00A3FF).withOpacity(0.08), 500),
          ),

          // 2. Main Content
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Sci-Fi Logo Section
                        const Text(
                          "SERO",
                          style: TextStyle(
                            color: Color(0xFF00FF11),
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 15,
                            shadows: [
                              Shadow(color: Color(0xFF00FF11), blurRadius: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "NEURAL UPLINK ESTABLISHED",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Glassmorphic Input Panel
                        _buildGlassPanel([
                          _buildInput(
                            "Username",
                            _userController,
                            Icons.person_outline_rounded,
                          ),
                          const Divider(color: Colors.white10, height: 1),
                          _buildInput(
                            "Password",
                            _passwordController,
                            Icons.lock_open_rounded,
                            isPass: true,
                          ),
                        ]),

                        const SizedBox(height: 40),

                        // Action Button
                        _buildActionButton("INITIALIZE SESSION", _handleLogin),

                        const SizedBox(height: 24),

                        // Footer
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: Text(
                            "NEW ENROLLMENT",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              letterSpacing: 2,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 20)],
      ),
    );
  }

  Widget _buildGlassPanel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.01),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildInput(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isPass = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: const Color(0xFF00FF11),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF00FF11).withOpacity(0.7),
          size: 20,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF00FF11,
              ).withOpacity(_isLoading ? 0.1 : 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          gradient: const LinearGradient(
            colors: [Color(0xFF064D00), Color(0xFF00FF11)],
          ),
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
