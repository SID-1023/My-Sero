import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../auth/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();

  String _userName = "Loading...";
  String _userHandle = "sero_user";
  String _userEmail = "";
  String _aiPersonality = "Standard Assistant";
  Color _selectedAccent = const Color(0xFF00FF11);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    ParseUser? currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _userName = currentUser.get<String>('username') ?? "Unknown User";
        _userHandle = currentUser.username ?? "user";
        _userEmail = currentUser.emailAddress ?? "No email linked";
        _aiPersonality =
            currentUser.get<String>('personality') ?? "Helpful Assistant";
        String? savedColor = currentUser.get<String>('accentColor');
        if (savedColor != null) {
          _selectedAccent = Color(int.parse(savedColor));
        }
      });
    }
  }

  Future<void> _updateAccentColor(Color newColor) async {
    HapticFeedback.selectionClick();
    ParseUser? user = await _authService.getCurrentUser();
    if (user != null) {
      user.set('accentColor', newColor.value.toString());
      final response = await user.save();
      if (response.success) {
        setState(() => _selectedAccent = newColor);
      }
    }
  }

  void _handleLogout() async {
    HapticFeedback.heavyImpact();
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
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showPersonalizationSheet() {
    final TextEditingController pController = TextEditingController(
      text: _aiPersonality,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Personalization",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _selectedAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAccent,
                ),
                onPressed: () async {
                  ParseUser? user = await _authService.getCurrentUser();
                  if (user != null) {
                    user.set('personality', pController.text.trim());
                    await user.save();
                    setState(() => _aiPersonality = pController.text.trim());
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text(
                  "Apply Core Logic",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Neural Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: _selectedAccent.withOpacity(0.1),
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
          const SizedBox(height: 32),
          _buildSectionHeader("System Configuration"),
          _buildSettingItem(
            Icons.psychology_outlined,
            "Personalization",
            subtitle: "Current Logic: $_aiPersonality",
            onTap: _showPersonalizationSheet,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Interface"),
          _buildSettingItem(
            Icons.color_lens_outlined,
            "Accent color",
            onTap: () => _showColorPicker(context),
            trailing: CircleAvatar(radius: 8, backgroundColor: _selectedAccent),
          ),
          _buildSettingItem(
            Icons.email_outlined,
            "Linked Email",
            trailingText: _userEmail,
          ),
          const SizedBox(height: 32),
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

  // UPDATED: COLOR PICKER WITH HORIZONTAL SCROLLING
  void _showColorPicker(BuildContext context) {
    final colors = [
      const Color(0xFF00FF11),
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.redAccent,
      const Color(0xFFFF006A),
      const Color(0xFF05FFA1),
      const Color(0xFF01CDFE),
      const Color(0xFFB967FF),
      const Color(0xFFFF8132),
      const Color(0xFF6300FF),
      const Color(0xFF00F2FF),
      const Color(0xFFADFF00),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        height: 140, // Increased height to prevent clipping
        child: Column(
          children: [
            const Text(
              "Neural Frequency",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final c = colors[index];
                  return GestureDetector(
                    onTap: () {
                      _updateAccentColor(c);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 24,
                        child: _selectedAccent == c
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
        leading: Icon(icon, color: color ?? _selectedAccent),
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
