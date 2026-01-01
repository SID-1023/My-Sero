import 'package:flutter/material.dart';
import 'auth_service.dart';

class SeroLoginPage extends StatefulWidget {
  const SeroLoginPage({super.key});

  @override
  State<SeroLoginPage> createState() => _SeroLoginPageState();
}

class _SeroLoginPageState extends State<SeroLoginPage> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
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
        // MATCHED: main.dart uses '/' for the home route
        Navigator.pushReplacementNamed(context, '/');
      } else {
        _showError("Signal Interrupted: ${response.error?.message}");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF2D55), // Aurora Red
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F), // Deep space background
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Close keyboard on tap
        child: Stack(
          children: [
            // Sci-Fi Background Glows
            Positioned(
              top: -100,
              left: -100,
              child: _buildGlow(const Color(0xFF00FF11).withOpacity(0.08)),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: _buildGlow(const Color(0xFF00A3FF).withOpacity(0.05)),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Header
                    const Text(
                      "SERO",
                      style: TextStyle(
                        color: Color(0xFF00FF11),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "NEURAL INTERFACE V1.0",
                      style: TextStyle(
                        color: const Color(0xFF00FF11).withOpacity(0.5),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Inputs
                    _buildInput(
                      "Username",
                      _userController,
                      Icons.person_outline,
                      TextInputType.name,
                    ),
                    const SizedBox(height: 20),
                    _buildInput(
                      "Password",
                      _passwordController,
                      Icons.lock_outline,
                      TextInputType.visiblePassword,
                      isPass: true,
                    ),

                    const SizedBox(height: 40),

                    // Login Button
                    _buildActionButton("INITIALIZE SESSION", _handleLogin),

                    const SizedBox(height: 20),

                    // Register Link
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                      ),
                      child: const Text(
                        "Create New Identity",
                        style: TextStyle(letterSpacing: 1),
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

  Widget _buildGlow(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  Widget _buildInput(
    String hint,
    TextEditingController controller,
    IconData icon,
    TextInputType type, {
    bool isPass = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FF11).withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: const Color(0xFF00FF11),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF00FF11), size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF064D00), Color(0xFF00FF11)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF11).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : onTap,
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
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
