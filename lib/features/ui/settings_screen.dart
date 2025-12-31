import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../voice/voice_input.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for demonstration - in a real app, these would come from a UserProvider
  String _userName = "Sidhu Umate";
  String _userHandle = "sidumate11";
  Color _selectedAccent = const Color(0xFFFF2D55);

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final provider = context.watch<VoiceInputProvider>();

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
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // ================= USER PROFILE SECTION =================
          const SizedBox(height: 20),
          Center(
            child: Hero(
              tag: 'profile_avatar',
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _selectedAccent.withOpacity(0.2),
                child: Text(
                  _userName.substring(0, 2).toUpperCase(),
                  style: TextStyle(fontSize: 24, color: _selectedAccent),
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
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Edit profile",
                style: TextStyle(color: Colors.white),
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
            Icons.work_outline,
            "Workspace",
            trailingText: "Personal",
          ),
          _buildSettingItem(
            Icons.star_outline,
            "Upgrade to Plus",
            color: Colors.amber,
          ),
          _buildSettingItem(
            Icons.email_outlined,
            "Email",
            trailingText: "sidumate11@gmail.com",
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
                boxShadow: [
                  BoxShadow(
                    color: _selectedAccent.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildSettingItem(
            Icons.logout,
            "Log out",
            color: Colors.redAccent,
            onTap: () {
              HapticFeedback.heavyImpact();
              // Add logout logic here
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ================= HELPERS & DIALOGS =================

  void _showEditProfileSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Profile",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Full Name",
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
              ),
              onChanged: (val) => setState(() => _userName = val),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _selectedAccent),
              onPressed: () => Navigator.pop(context),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      const Color(0xFFFF2D55),
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
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
                  child: CircleAvatar(backgroundColor: c, radius: 20),
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
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
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
        onTap:
            onTap ??
            () {
              HapticFeedback.lightImpact();
            },
      ),
    );
  }
}
