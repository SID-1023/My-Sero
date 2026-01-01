import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../voice/voice_input.dart';
import '../auth/auth_service.dart'; // Import your AuthService

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  // Dynamic User Data
  String _userName = "Loading...";
  String _userHandle = "sero_user";
  String _userEmail = "";
  Color _selectedAccent = const Color(0xFF00FF11); // Matched your Sero Green

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 1. FETCH ACTUAL USER FROM BACK4APP
  Future<void> _loadUserData() async {
    ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      setState(() {
        // Use 'username' or a custom 'fullName' field if you created one
        _userName = currentUser.get<String>('username') ?? "Unknown User";
        _userHandle = currentUser.username ?? "user";
        _userEmail = currentUser.emailAddress ?? "No email linked";
      });
    }
  }

  // 2. LOGOUT LOGIC
  void _handleLogout() async {
    HapticFeedback.heavyImpact();

    // Show confirmation dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          "Terminate Session?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will disconnect your neural link to Sero.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "LOGOUT",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        // Go back to login and clear navigation stack
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  // 3. UPDATE PROFILE LOGIC
  Future<void> _updateProfile(String newName) async {
    ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      currentUser.set(
        'username',
        newName,
      ); // Or use a custom field like 'fullName'
      final response = await currentUser.save();

      if (response.success) {
        setState(() => _userName = newName);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Synced Successfully")),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Neural Settings",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 20),
          // PROFILE SECTION
          Center(
            child: Hero(
              tag: 'profile_avatar',
              child: CircleAvatar(
                radius: 45,
                backgroundColor: _selectedAccent.withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedAccent.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _userName.isNotEmpty
                        ? _userName.substring(0, 1).toUpperCase()
                        : "S",
                    style: TextStyle(
                      fontSize: 32,
                      color: _selectedAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _userName,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              "@$_userHandle",
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => _showEditProfileSheet(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Edit Identity",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader("My Sero AI"),
          _buildSettingItem(
            Icons.face,
            "Personalization",
            subtitle: "Customize AI behavior",
          ),
          _buildSettingItem(
            Icons.widgets_outlined,
            "Apps",
            subtitle: "Connect external tools",
          ),

          const SizedBox(height: 24),
          _buildSectionHeader("Account"),
          _buildSettingItem(
            Icons.email_outlined,
            "Email",
            trailingText: _userEmail,
          ),
          _buildSettingItem(
            Icons.star_outline,
            "Upgrade to Plus",
            color: Colors.amber,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader("Appearance"),
          _buildSettingItem(
            Icons.color_lens_outlined,
            "Accent color",
            onTap: () => _showColorPicker(context),
            trailing: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _selectedAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 32),
          // LOGOUT BUTTON
          _buildSettingItem(
            Icons.power_settings_new,
            "Terminate Session",
            color: Colors.redAccent,
            onTap: _handleLogout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ================= HELPERS & DIALOGS =================

  void _showEditProfileSheet(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Update Identity",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Username / Full Name",
                labelStyle: TextStyle(color: Colors.white38),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FF11)),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAccent,
                ),
                onPressed: () {
                  _updateProfile(nameController.text.trim());
                  Navigator.pop(context);
                },
                child: const Text(
                  "Save to Cloud",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Color picker and build helper methods remain similar but updated with Haptics...
  void _showColorPicker(BuildContext context) {
    final colors = [
      const Color(0xFF00FF11),
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.redAccent,
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAccent = c);
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 22,
                    child: _selectedAccent == c
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title, {
    String? subtitle,
    String? trailingText,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.white70),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              )
            : null,
        trailing:
            trailing ??
            (trailingText != null
                ? Text(
                    trailingText,
                    style: const TextStyle(color: Colors.white38),
                  )
                : const Icon(Icons.chevron_right, color: Colors.white24)),
        onTap: onTap ?? () => HapticFeedback.lightImpact(),
      ),
    );
  }
}
