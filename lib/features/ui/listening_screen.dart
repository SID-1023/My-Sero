import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // 10s duration for a slow, hypnotic rotation or pulse in the GlowingOrbPainter
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceInputProvider>();
    final size = MediaQuery.of(context).size;
    final color = provider.emotionColor;

    return Scaffold(
      backgroundColor: const Color(0xFF050507), // Deeper Obsidian
      body: Stack(
        children: [
          // 1. Dynamic Ambient Background Glow
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            top: provider.isListening ? -100 : -200,
            left: -50,
            right: -50,
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 2. Sophisticated Status Indicator
                _buildStatusPill(provider),

                const Spacer(),

                // 3. The Central Intelligence Orb
                // Wrapped in an AnimatedScale to pulse slightly when listening
                AnimatedScale(
                  scale: provider.isListening ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    width: size.width * 0.75,
                    height: size.width * 0.75,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) {
                        return CustomPaint(
                          painter: GlowingOrbPainter(
                            progress: _controller.value,
                            color: color,
                            // Pass additional states if your painter supports them
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // 4. Transcription Area with improved legibility
                _buildTranscription(provider),

                const Spacer(),

                // 5. Contextual Action Button
                _buildActionButton(provider),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Assistant response overlay
          const AssistantResponseBubble(),
        ],
      ),
    );
  }

  Widget _buildStatusPill(VoiceInputProvider provider) {
    String status = "IDLE";
    if (provider.isListening) status = "LISTENING";
    if (provider.isThinking) status = "THINKING";
    if (provider.isSpeaking) status = "SPEAKING";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: provider.emotionColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: provider.emotionColor, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscription(VoiceInputProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedOpacity(
        opacity: provider.lastWords.isNotEmpty ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 300),
        child: Text(
          provider.lastWords.isNotEmpty
              ? provider.lastWords
              : "Sero is listening...",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 20,
            height: 1.5,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(VoiceInputProvider provider) {
    return AnimatedOpacity(
      opacity: provider.isListening ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !provider.isListening,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            provider.stopListening();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_rounded, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  "STOP RECORDING",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
