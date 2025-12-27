import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../voice/voice_input.dart';
import '../../widgets/glowing_orb.dart';
import '../../widgets/assistant_response.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
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
    final provider = context.watch<VoiceInputProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: Stack(
        children: [
          // ===== Ambient background glow =====
          Positioned(
            top: -160,
            left: size.width * 0.1,
            right: size.width * 0.1,
            child: Container(
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.emotionColor.withOpacity(0.18),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 110, sigmaY: 110),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ===== STATUS TEXT =====
                Text(
                  provider.isListening
                      ? "LISTENING"
                      : provider.isThinking
                      ? "THINKING"
                      : provider.isSpeaking
                      ? "SPEAKING"
                      : "IDLE",
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                  ),
                ),

                const Spacer(),

                // ===== CENTER ORB =====
                SizedBox(
                  width: 280,
                  height: 280,
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

                const SizedBox(height: 30),

                // ===== LIVE TRANSCRIPTION =====
                AnimatedOpacity(
                  opacity: provider.lastWords.isNotEmpty ? 1 : 0.4,
                  duration: const Duration(milliseconds: 250),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      provider.lastWords.isNotEmpty
                          ? provider.lastWords
                          : "Speak naturally…",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ===== STOP LISTENING BUTTON =====
                if (provider.isListening)
                  GestureDetector(
                    onTap: provider.stopListening,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      child: const Text(
                        "Tap to Stop",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Assistant response overlay (same as HomeScreen)
          const AssistantResponseBubble(),
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
