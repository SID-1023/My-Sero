import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../voice/voice_input.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/assistant_response.dart';
import '../../widgets/glowing_orb.dart';
import 'keyboard_input_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = context.watch<VoiceInputProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: Stack(
        children: [
          // ================= BACKGROUND AMBIENT GLOW =================
          Positioned(
            top: -150,
            left: size.width * 0.1,
            right: size.width * 0.1,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.emotionColor.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox(),
              ),
            ),
          ),

          // ================= MAIN CONTENT =================
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildHeader(),

                const Spacer(),

                // ================= MAIN ORB =================
                SizedBox(
                  width: 320,
                  height: 320,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return CustomPaint(
                        painter: GlowingOrbPainter(
                          progress: _controller.value,
                          color: provider.emotionColor,
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(),

                _buildKeyboardHint(context),

                _buildBottomNav(provider),
              ],
            ),
          ),

          // ================= ASSISTANT RESPONSE OVERLAY =================
          const AssistantResponseBubble(),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          "I CAN SEARCH NEW CONTACTS",
          style: TextStyle(
            color: Color(0xFFD50000),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: 12),
        Text(
          "What Can I Do for\nYou Today?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFB3B3),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  // ================= KEYBOARD HINT =================
  Widget _buildKeyboardHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KeyboardInputScreen()),
          );
        },
        child: const Opacity(
          opacity: 0.3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "Use Keyboard",
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= BOTTOM NAV =================
  Widget _buildBottomNav(VoiceInputProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.person_outline, color: Colors.white38),

          // ================= CHAT / NEW CHAT ICONS =================
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white38,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white38),
                onPressed: () {
                  final chatProvider = context.read<ChatProvider>();
                  chatProvider.createNewChat();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ],
          ),

          // ================= MIC BUTTON =================
          SeroMicButton(controller: _controller),

          IconButton(
            icon: Icon(
              Icons.tune,
              color: provider.autoListenAfterResponse
                  ? Colors.greenAccent
                  : Colors.white38,
            ),
            onPressed: () {
              provider.setAutoListenAfterResponse(
                !provider.autoListenAfterResponse,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
