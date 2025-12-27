import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../voice/voice_input.dart';
import '../../widgets/assistant_response.dart';

class KeyboardInputScreen extends StatefulWidget {
  const KeyboardInputScreen({super.key});

  @override
  State<KeyboardInputScreen> createState() => _KeyboardInputScreenState();
}

class _KeyboardInputScreenState extends State<KeyboardInputScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus keyboard on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _handleSubmission(BuildContext context) {
    if (_isSending) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    // 1. Force the keyboard to hide instantly
    FocusManager.instance.primaryFocus?.unfocus();

    final provider = context.read<VoiceInputProvider>();

    // 2. Cancel any active voice listening
    provider.stopListening();

    // 3. Execute the shared backend logic
    provider.sendTextInput(text);

    // 4. Clear input and exit back to Home
    _controller.clear();
    Navigator.pop(context);
  }

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

                // Input Field Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction
                          .send, // Changes keyboard 'Enter' to 'Send'
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: "Type naturally…",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSubmission(context),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Visual Send Button
                GestureDetector(
                  onTap: () => _handleSubmission(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _isSending
                          ? Colors.white10
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      _isSending ? "Sending..." : "Send",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),

          // Reuses your bubble widget for consistency
          const AssistantResponseBubble(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
