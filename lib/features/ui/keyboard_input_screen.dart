import 'dart:ui';
import 'package:flutter/material.dart';

import '../../widgets/assistant_response.dart';
import '../../widgets/chat_composer.dart';

class KeyboardInputScreen extends StatefulWidget {
  const KeyboardInputScreen({super.key});

  @override
  State<KeyboardInputScreen> createState() => _KeyboardInputScreenState();
}

class _KeyboardInputScreenState extends State<KeyboardInputScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: Stack(
        children: [
          // Background blur layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Header section
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "TYPE TO SERO",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),

                const Spacer(),
              ],
            ),
          ),

          // Reuses your bubble widget for consistency
          const AssistantResponseBubble(),

          // Floating Chat Composer anchored to bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: const ChatComposer(
                autoClose: true,
                autoFocus: true,
                navigateToChatOnSend: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
