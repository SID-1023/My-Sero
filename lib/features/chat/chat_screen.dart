import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// 1. Same directory imports - remove the ../../ pathing
import 'chat_provider.dart';

// 2. Voice input is in lib/features/voice/ (one level up, then into voice)
import '../voice/voice_input.dart';

// 3. Widgets are in lib/widgets/ (two levels up from features/chat/ then into widgets)
import '../../../widgets/chat_bubble.dart';
import '../../../widgets/chat_composer.dart';
import '../../../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final bool focusComposer;

  const ChatScreen({super.key, this.focusComposer = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  int _prevMessageCount = 0;

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart, // Matches your high-end UI feel
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch allows the UI to rebuild when providers change
    final chatProvider = context.watch<ChatProvider>();
    final voiceProvider = context.watch<VoiceInputProvider>();

    final messages = chatProvider.messages;
    final bool isTyping = chatProvider.isTyping;

    // Trigger auto-scroll when a new message arrives or Sero starts typing
    if (messages.length != _prevMessageCount || isTyping) {
      _prevMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050507), // Deep Obsidian
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, chatProvider, voiceProvider),
      body: Stack(
        children: [
          // Dynamic Ambient Background Glow - Expanded for better visual depth
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(seconds: 3),
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    voiceProvider.emotionColor.withOpacity(0.12),
                    voiceProvider.emotionColor.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: messages.isEmpty && !isTyping
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
                        reverse: true, // Key for chat: builds from bottom up
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isTyping && index == 0) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 16.0,
                                  horizontal: 8.0,
                                ),
                                child: TypingIndicator(),
                              ),
                            );
                          }

                          final messageIndex = isTyping ? index - 1 : index;
                          final message =
                              messages[messages.length - 1 - messageIndex];

                          return ChatBubble(message: message);
                        },
                      ),
              ),

              // Glassmorphic Input Section
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F13).withOpacity(0.8),
                      border: const Border(
                        top: BorderSide(color: Colors.white10, width: 0.5),
                      ),
                    ),
                    child: ChatComposer(autoFocus: widget.focusComposer),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ChatProvider chat,
    VoiceInputProvider voice,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(85),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: const Color(0xFF050507).withOpacity(0.7),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 32,
                color: Colors.white70,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.activeChat?.title.toUpperCase() ?? 'SERO TERMINAL',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSystemStatusBadge(voice),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                onPressed: () => _showClearDialog(context, chat),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBadge(VoiceInputProvider voice) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: voice.emotionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: voice.emotionColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: voice.emotionColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: voice.emotionColor,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            voice.isListening ? "ENCRYPTED UPLINK" : "SYSTEM STABLE",
            style: TextStyle(
              fontSize: 8,
              color: voice.emotionColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_moon_outlined,
            size: 56,
            color: Colors.white.withOpacity(0.03),
          ),
          const SizedBox(height: 24),
          Text(
            "NO LOGS DETECTED",
            style: TextStyle(
              color: Colors.white.withOpacity(0.1),
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, ChatProvider provider) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF14141B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text(
            "Purge Session?",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "This will permanently erase all terminal logs from the current session.",
            style: TextStyle(color: Colors.white60),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "ABORT",
                style: TextStyle(color: Colors.white38),
              ),
            ),
            TextButton(
              onPressed: () {
                provider.clear();
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              child: const Text(
                "PURGE",
                style: TextStyle(
                  color: Color(0xFFB11226),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
