import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../voice/voice_input.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/assistant_response.dart';
import '../../widgets/glowing_orb.dart';
import 'keyboard_input_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _badgePulse;
  Offset _pointerPos = Offset.zero;
  double _manualRotation = 0.0;
  bool _isBackendLive = false;
  Color _neuralAccentColor = const Color(0xFF00FF11);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _badgePulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.2, curve: Curves.easeInOut),
      ),
    );

    _loadNeuralData();
    _initVoiceCommandListener();
  }

  /// Sets up a listener to watch for "Play ... on Spotify" commands
  void _initVoiceCommandListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = Provider.of<VoiceInputProvider>(
        context,
        listen: false,
      );

      voiceProvider.addListener(() {
        // Triggered when transcription finishes
        if (!voiceProvider.isListening &&
            voiceProvider.lastTranscript.isNotEmpty) {
          _handleSpotifyIntent(voiceProvider.lastTranscript);
        }
      });
    });
  }

  /// Regex logic to extract song name and launch Spotify
  Future<void> _handleSpotifyIntent(String transcript) async {
    final text = transcript.toLowerCase();

    if (text.contains('play') && text.contains('spotify')) {
      // Matches "play [song name] on spotify" or "play [song name] in spotify"
      final RegExp regex = RegExp(r"play\s+(.*?)\s+(?:on|in)\s+spotify");
      final match = regex.firstMatch(text);

      if (match != null) {
        String songName = match.group(1) ?? "";
        if (songName.isNotEmpty) {
          final Uri spotifyUri = Uri.parse(
            "spotify:search:${Uri.encodeComponent(songName)}",
          );

          if (await canLaunchUrl(spotifyUri)) {
            await launchUrl(spotifyUri);
            HapticFeedback.heavyImpact();
          } else {
            // Fallback to web search if app not found
            final Uri webUri = Uri.parse(
              "https://open.spotify.com/search/${Uri.encodeComponent(songName)}",
            );
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
          }
        }
      }
    }
  }

  Future<void> _loadNeuralData() async {
    try {
      final ParseResponse response = await Parse().healthCheck();
      setState(() => _isBackendLive = response.success);
    } catch (_) {
      setState(() => _isBackendLive = false);
    }

    ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      String? savedColor = currentUser.get<String>('accentColor');
      if (savedColor != null) {
        setState(() => _neuralAccentColor = Color(int.parse(savedColor)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final provider = context.watch<VoiceInputProvider>();
    final Color activeColor = provider.isListening
        ? provider.emotionColor
        : _neuralAccentColor;

    if (_pointerPos == Offset.zero) {
      _pointerPos = Offset(size.width / 2, size.height / 2);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080101),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pointerPos = details.localPosition;
            _manualRotation += details.delta.dx * 0.01;
          });
        },
        child: SeroAuraEffect(
          touchPosition: _pointerPos,
          color: activeColor,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildHeader(activeColor),
                    const Spacer(),
                    _buildOrb(size, activeColor),
                    const Spacer(),
                    _buildKeyboardHint(context, activeColor),
                    _buildBottomNav(activeColor),
                  ],
                ),
              ),
              const AssistantResponseBubble(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrb(Size size, Color activeColor) {
    return SizedBox(
      width: 320,
      height: 320,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX((_pointerPos.dy - size.height / 2) * -0.0005)
              ..rotateY((_pointerPos.dx - size.width / 2) * 0.0005)
              ..rotateZ(_manualRotation),
            child: CustomPaint(
              painter: GlowingOrbPainter(
                progress: _controller.value,
                color: activeColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Color themeColor) {
    return Column(
      children: [
        FadeTransition(
          opacity: _badgePulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: themeColor.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isBackendLive ? themeColor : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isBackendLive ? "SERO SYNCED" : "OFFLINE",
                  style: TextStyle(
                    color: themeColor.withOpacity(0.9),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "What Can I Do for\nYou Today?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: themeColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardHint(BuildContext context, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const KeyboardInputScreen())),
        child: Opacity(
          opacity: 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, size: 16, color: themeColor),
              const SizedBox(width: 8),
              Text(
                "Use Keyboard",
                style: TextStyle(fontSize: 13, color: themeColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color themeColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: themeColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline,
              color: themeColor.withOpacity(0.4),
            ),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
          ),
          SeroMicButton(controller: _controller),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: themeColor),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadNeuralData();
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

// --- FX ---
class SeroAuraEffect extends StatelessWidget {
  final Widget child;
  final Offset touchPosition;
  final Color color;
  const SeroAuraEffect({
    super.key,
    required this.child,
    required this.touchPosition,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuraPainter(touchPosition: touchPosition, baseColor: color),
      child: child,
    );
  }
}

class AuraPainter extends CustomPainter {
  final Offset touchPosition;
  final Color baseColor;
  AuraPainter({required this.touchPosition, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (touchPosition.dx / size.width) * 2 - 1,
          (touchPosition.dy / size.height) * 2 - 1,
        ),
        radius: 0.8,
        colors: [
          baseColor.withOpacity(0.12),
          baseColor.withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(AuraPainter oldDelegate) =>
      oldDelegate.touchPosition != touchPosition ||
      oldDelegate.baseColor != baseColor;
}
