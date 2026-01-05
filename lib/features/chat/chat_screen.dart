import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// Directory imports
import 'chat_provider.dart';
import '../voice/voice_input.dart';
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

  // Dynamic Accent Sync from Back4app
  Color _accentColor = const Color(0xFFFF006A);

  @override
  void initState() {
    super.initState();
    _loadNeuralColor();
  }

  /// Syncs the screen with the color selected in Settings
  Future<void> _loadNeuralColor() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user != null) {
      final colorHex = user.get<String>('accentColor');
      if (colorHex != null) {
        setState(() {
          _accentColor = Color(int.parse(colorHex));
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    // UPDATED LOGIC: We no longer check voiceProvider.emotionColor.
    // The UI is now locked to your selected accent color.
    final Color activeColor = _accentColor;

    final messages = chatProvider.messages;
    final bool isTyping = chatProvider.isTyping;

    if (messages.length != _prevMessageCount || isTyping) {
      _prevMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080101), // Void Black
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, chatProvider, activeColor),
      body: Stack(
        children: [
          // ================= GHOST AMBIENT GLOW =================
          Positioned(
            top: -150,
            right: -100,
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    activeColor.withOpacity(0.15), // Neon light leak
                    activeColor.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: messages.isEmpty && !isTyping
                    ? _buildEmptyState(activeColor)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 130, 16, 20),
                        reverse: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isTyping && index == 0) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                  horizontal: 8.0,
                                ),
                                child: TypingIndicator(color: activeColor),
                              ),
                            );
                          }

                          final messageIndex = isTyping ? index - 1 : index;
                          final message =
                              messages[messages.length - 1 - messageIndex];

                          return ChatBubble(
                            message: message,
                            accentColor: activeColor,
                          );
                        },
                      ),
              ),

              // ================= GHOST GLASS COMPOSER =================
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border(
                        top: BorderSide(
                          color: activeColor.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ===== NEW FEATURE START =====
                        // Dynamic Abort Button visible only during thinking/voice processing
                        if (isTyping || chatProvider.isListening)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _buildAbortButton(
                                context, chatProvider, activeColor),
                          ),
                        // ===== NEW FEATURE END =====
                        ChatComposer(autoFocus: widget.focusComposer),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== NEW FEATURE START =====
  Widget _buildAbortButton(
      BuildContext context, ChatProvider provider, Color activeColor) {
    return InkWell(
      onTap: () {
        HapticFeedback.vibrate();
        provider.abortProcess();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: activeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activeColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_circle_rounded, color: activeColor, size: 16),
            const SizedBox(width: 8),
            Text(
              "ABORT UPLINK",
              style: TextStyle(
                color: activeColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ===== NEW FEATURE END =====

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ChatProvider chat,
    Color activeColor,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: Colors.black.withOpacity(0.2),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: activeColor.withOpacity(0.6),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.activeChat?.title.toUpperCase() ?? 'NEURAL LINK',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 5.0,
                    fontWeight: FontWeight.w900,
                    color: activeColor,
                    shadows: [
                      Shadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 0), // ✅ Correct
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildSystemStatusBadge(activeColor, chat.isTyping),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: activeColor.withOpacity(0.6),
                ),
                onPressed: () => _showClearDialog(context, chat, activeColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBadge(Color activeColor, bool isProcessing) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isProcessing ? Colors.orange : activeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: isProcessing ? Colors.orange : activeColor,
                    blurRadius: 8)
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isProcessing ? "PROCESSING..." : "UPLINK STABLE",
            style: TextStyle(
              fontSize: 8,
              color: activeColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color activeColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grain_rounded,
            size: 48,
            color: activeColor.withOpacity(0.1),
          ),
          const SizedBox(height: 20),
          Text(
            "WAITING FOR NEURAL INPUT",
            style: TextStyle(
              color: activeColor.withOpacity(0.2),
              fontSize: 9,
              letterSpacing: 6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(
    BuildContext context,
    ChatProvider provider,
    Color activeColor,
  ) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF080101).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: activeColor.withOpacity(0.2)),
          ),
          title: const Text(
            "PURGE SESSION?",
            style: TextStyle(color: Colors.white, letterSpacing: 1),
          ),
          content: Text(
            "Permanent removal of all terminal logs for this exchange.",
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "ABORT",
                style: TextStyle(color: activeColor.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                provider.clear();
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              child: Text(
                "PURGE",
                style: TextStyle(
                  color: activeColor,
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
