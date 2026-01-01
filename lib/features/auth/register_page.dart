import 'dart:ui';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class SeroRegisterPage extends StatefulWidget {
  const SeroRegisterPage({super.key});

  @override
  State<SeroRegisterPage> createState() => _SeroRegisterPageState();
}

class _SeroRegisterPageState extends State<SeroRegisterPage>
    with SingleTickerProviderStateMixin {
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _userController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_userController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _emailController.text.isEmpty) {
      _showStatus("Fields cannot be empty.", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final response = await _authService.signUp(
      _userController.text.trim(),
      _passwordController.text.trim(),
      _emailController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (response.success) {
        _showStatus("Identity Synchronized.", isError: false);
        Future.delayed(
          const Duration(seconds: 1),
          () => Navigator.pop(context),
        );
      } else {
        _showStatus(
          "Protocol Failed: ${response.error?.message}",
          isError: true,
        );
      }
    }
  }

  void _showStatus(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(letterSpacing: 1, fontSize: 13),
        ),
        backgroundColor: isError
            ? const Color(0xFFFF2D55)
            : const Color(0xFF00FF11),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507), // Ultra dark obsidian
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Background Visuals
          _buildAuraGlow(
            Alignment.topRight,
            const Color(0xFF00FF11).withOpacity(0.1),
          ),
          _buildAuraGlow(
            Alignment.bottomLeft,
            const Color(0xFFCF9FFF).withOpacity(0.08),
          ),

          // 2. Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "NEW\nIDENTITY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "ESTABLISHING NEURAL PARAMETERS",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 50),

                    // 3. Frosted Glass Panel
                    _buildGlassPanel([
                      _buildInput(
                        "User Signature",
                        _userController,
                        Icons.person_add_alt_1_rounded,
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      _buildInput(
                        "Communication Channel",
                        _emailController,
                        Icons.alternate_email_rounded,
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      _buildInput(
                        "Access Code",
                        _passwordController,
                        Icons.key_rounded,
                        isPass: true,
                      ),
                    ]),

                    const SizedBox(height: 40),

                    // 4. Action Button
                    _buildNeonButton("AUTHORIZE CREATION", _handleRegister),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuraGlow(Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 350,
        height: 350,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassPanel(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
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
          color: const Color(0xFFCF9FFF).withOpacity(0.6),
          size: 22,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 22,
          horizontal: 20,
        ),
      ),
    );
  }

  Widget _buildNeonButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 65,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF064D00), Color(0xFF00FF11)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF11).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}
