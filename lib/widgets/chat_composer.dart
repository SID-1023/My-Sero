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
    super.key,
    this.autoClose = false,
    this.autoFocus = false,
    this.navigateToChatOnSend = false,
    this.onSend,
  });

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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final voiceProvider = context.read<VoiceInputProvider>();

    try {
      if (widget.onSend != null) {
        await widget.onSend!(text);
      } else {
        voiceProvider.stopListening();
        voiceProvider.sendTextInput(
          text,
          suppressAutoListen: true,
          showOverlay: false,
        );
      }

      _controller.clear();

      if (widget.autoClose) {
        _focusNode.unfocus();
        await Future.delayed(const Duration(milliseconds: 150));

        if (widget.navigateToChatOnSend && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ChatScreen(focusComposer: true),
            ),
          );
        } else if (mounted) {
          Navigator.of(context).maybePop();
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceProvider = context.watch<VoiceInputProvider>();
    final isListening = voiceProvider.isListening;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutQuad,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Voice Toggle Button
                      IconButton(
                        icon: Icon(
                          isListening ? Icons.graphic_eq : Icons.mic,
                          color: isListening
                              ? const Color(0xFF1AFF6B)
                              : Colors.white70,
                        ),
                        onPressed: () {
                          if (isListening)
                            voiceProvider.stopListening();
                          else
                            voiceProvider.startListening();
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: isListening
                                ? 'Sero is listening...'
                                : 'Type a message...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Optimized Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _handleSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListening
                          ? const Color(0xFFB11226)
                          : const Color(0xFF1AFF6B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isSending
                          ? 'SENDING...'
                          : (isListening ? 'STOP & SEND' : 'SEND MESSAGE'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
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
    _focusNode.dispose();
    super.dispose();
  }
}
