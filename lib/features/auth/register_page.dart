import 'package:flutter/material.dart';
import 'auth_service.dart';

class SeroRegisterPage extends StatefulWidget {
  const SeroRegisterPage({super.key});

  @override
  State<SeroRegisterPage> createState() => _SeroRegisterPageState();
}

class _SeroRegisterPageState extends State<SeroRegisterPage> {
  final _userController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_userController.text.isEmpty || _passwordController.text.isEmpty)
      return;

    setState(() => _isLoading = true);
    final response = await _authService.signUp(
      _userController.text.trim(),
      _passwordController.text.trim(),
      _emailController.text.trim(),
    );

    if (response.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Identity Created."),
            backgroundColor: Color.fromARGB(255, 0, 255, 17),
          ),
        );
        Navigator.pop(context); // Go back to login
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Creation Failed: ${response.error?.message}"),
            backgroundColor: const Color(0xFFFF2D55),
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Text(
              "NEW IDENTITY",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 50),
            _buildInput("Username", _userController, Icons.person_add_alt),
            const SizedBox(height: 20),
            _buildInput(
              "Email Address",
              _emailController,
              Icons.email_outlined,
            ),
            const SizedBox(height: 20),
            _buildInput(
              "Access Password",
              _passwordController,
              Icons.security_outlined,
              isPass: true,
            ),
            const SizedBox(height: 40),
            _buildActionButton("CREATE", _handleRegister),
          ],
        ),
      ),
    );
  }

  // Reuse the same _buildInput and _buildActionButton UI helpers from the login page code for consistency
  Widget _buildInput(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isPass = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xFFCF9FFF),
          ), // Ghost Purple for registration icons
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color.fromARGB(255, 0, 255, 17)),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(
                  label,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 0, 255, 17),
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
