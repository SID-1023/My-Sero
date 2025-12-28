import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/voice/voice_input.dart';

import '../features/chat/chat_screen.dart';

class ChatComposer extends StatefulWidget {
  final bool autoClose;
  final bool autoFocus;
  final bool navigateToChatOnSend;
  final Future<void> Function(String)? onSend;

  const ChatComposer({
    Key? key,
    this.autoClose = false,
    this.autoFocus = false,
    this.navigateToChatOnSend = false,
    this.onSend,
  }) : super(key: key);

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      // Delay focus slightly to avoid Android IME focus fighting during
      // route transitions (prevents keyboard flicker / focus loss).
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      });
    }
  }

  void _send(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final provider = context.read<VoiceInputProvider>();

    if (widget.onSend != null) {
      await widget.onSend!(text);
    } else {
      // Stop listening if active and send as keyboard input (no overlay, no auto listen)
      provider.stopListening();
      provider.sendTextInput(
        text,
        suppressAutoListen: true,
        showOverlay: false,
      );
    }

    _controller.clear();

    setState(() => _isSending = false);

    if (widget.autoClose) {
      // Close keyboard screen and optionally navigate to the Chat screen so user can read the reply
      if (widget.navigateToChatOnSend) {
        // Unfocus first to avoid IME panicking, then wait a short moment for the
        // system keyboard to settle before replacing the route. This prevents a
        // single frozen blurred frame being rendered on some Android devices.
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 120));

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ChatScreen(focusComposer: true),
            transitionDuration: const Duration(milliseconds: 120),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      } else {
        // If we're just popping the keyboard input screen, also wait for the
        // IME to settle after unfocusing so the blurred route does not linger.
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 120));
        Navigator.of(context).maybePop();
      }
    }
  }

  void _toggleVoice(BuildContext context) {
    final provider = context.read<VoiceInputProvider>();
    if (provider.isListening) {
      provider.stopListening();
    } else {
      provider.startListening();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottom + 12),
      child: SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            margin: const EdgeInsets.only(
              top: 12,
              left: 12,
              right: 12,
              bottom: 0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text composer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mic, color: Colors.white70),
                        onPressed: () => _toggleVoice(context),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _send(context),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Full-width CTA
                SizedBox(
                  width: double.infinity,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (_, value, __) {
                      final isEmpty = value.text.trim().isEmpty;
                      return ElevatedButton(
                        onPressed: isEmpty || _isSending
                            ? null
                            : () => _send(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1AFF6B),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isSending ? 'Sending...' : 'Send',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ), // Column
          ), // Container
        ), // BackdropFilter
      ), // SafeArea
    ); // AnimatedPadding
  }
}
