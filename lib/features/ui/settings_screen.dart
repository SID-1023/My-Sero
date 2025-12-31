import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../voice/voice_input.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          // User Profile Section
          const SizedBox(height: 20),
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white24,
              child: Text(
                "SU",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              "Sidhu Umate",
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Center(
            child: Text("sidumate11", style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
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
            trailing: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFFF2D55),
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 24),
          _buildSettingItem(Icons.logout, "Log out", color: Colors.redAccent),
          const SizedBox(height: 40),
        ],
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
        onTap: () {},
      ),
    );
  }
}
