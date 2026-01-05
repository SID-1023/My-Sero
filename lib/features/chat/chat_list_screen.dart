import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';

// Directory imports
import 'chat_provider.dart';
import 'chat_screen.dart';

// Assuming these exist in your project structure
import '../../core/ui/ui_preview.dart';
import '../../core/ui/sero_chat_tile.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Default to your Supernova Pink or a neutral grey until loaded
  Color _accentColor = const Color(0xFFFF006A);

  // ===== NEW FEATURE START =====
  bool _isSelectionMode = false;
  final List<String> _selectedSessionIds = [];
  // ===== NEW FEATURE END =====

  @override
  void initState() {
    super.initState();
    _loadNeuralColor();
  }

  /// Syncs the color with your Settings/Back4app
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

  void _navigateToChat(BuildContext context) {
    FocusScope.of(context).unfocus();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChatScreen()))
        .then((_) => _loadNeuralColor()); // Refresh color when coming back
  }

  // ===== NEW FEATURE START =====
  /// Toggles the selection of a session for bulk deletion
  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
        if (_selectedSessionIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  /// Selects or deselects all available sessions
  void _toggleSelectAll(List<dynamic> chats) {
    setState(() {
      if (_selectedSessionIds.length == chats.length) {
        _selectedSessionIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedSessionIds.clear();
        _selectedSessionIds.addAll(chats.map((c) => c.id.toString()));
      }
    });
  }

  /// Triggers the bulk deletion of selected sessions
  Future<void> _handleBulkDelete(ChatProvider provider) async {
    HapticFeedback.heavyImpact();
    await provider.deleteMultipleSessions(List.from(_selectedSessionIds));
    setState(() {
      _selectedSessionIds.clear();
      _isSelectionMode = false;
    });
  }
  // ===== NEW FEATURE END =====

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF080101), // Pure "Void" Black
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? "${_selectedSessionIds.length} SELECTED"
              : "NEURAL ARCHIVE",
          style: TextStyle(
            color: _accentColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: _isSelectionMode ? 2 : 5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedSessionIds.clear();
                }),
              )
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        // ===== NEW FEATURE START =====
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                  _selectedSessionIds.length == provider.chats.length
                      ? Icons.deselect
                      : Icons.select_all,
                  color: Colors.white70),
              onPressed: () => _toggleSelectAll(provider.chats),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: () => _handleBulkDelete(provider),
            ),
          ] else if (provider.chats.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined,
                  color: _accentColor.withOpacity(0.5)),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
        ],
        // ===== NEW FEATURE END =====
      ),
      body: provider.chats.isEmpty
          ? _buildEmptyState(context, provider)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: provider.chats.length,
              itemBuilder: (_, i) {
                final chat = provider.chats[i];
                return _buildGhostTile(chat, provider, context);
              },
            ),

      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.createNewChat();
                _navigateToChat(context);
              },
              backgroundColor: _accentColor,
              elevation: 20,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.add_circle_outline, color: Colors.black),
              label: const Text(
                "NEW EXCHANGE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }

  Widget _buildGhostTile(
    dynamic chat,
    ChatProvider provider,
    BuildContext context,
  ) {
    // ===== NEW FEATURE START =====
    final bool isSelected = _selectedSessionIds.contains(chat.id.toString());
    // ===== NEW FEATURE END =====

    return Dismissible(
      key: Key(chat.id.toString()),
      direction: _isSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.redAccent),
      ),
      onDismissed: (_) {
        // ===== NEW FEATURE START =====
        provider.deleteChat(chat);
        HapticFeedback.mediumImpact();
        // ===== NEW FEATURE END =====
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withOpacity(0.05)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? _accentColor : _accentColor.withOpacity(0.1),
              width: isSelected ? 1.5 : 0.5),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: _isSelectionMode
              ? Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? _accentColor : Colors.white24,
                )
              : CircleAvatar(
                  backgroundColor: _accentColor.withOpacity(0.1),
                  child:
                      Icon(Icons.bubble_chart, color: _accentColor, size: 20),
                ),
          title: Text(
            chat.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          subtitle: Text(
            chat.messages.isNotEmpty
                ? chat.messages.last.text
                : "Empty transmission...",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
          trailing: _isSelectionMode
              ? null
              : Icon(
                  Icons.arrow_forward_ios,
                  color: _accentColor.withOpacity(0.2),
                  size: 14,
                ),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(chat.id.toString());
            } else {
              provider.openChat(chat);
              _navigateToChat(context);
            }
          },
          // ===== NEW FEATURE START =====
          onLongPress: () {
            if (!_isSelectionMode) {
              HapticFeedback.heavyImpact();
              setState(() {
                _isSelectionMode = true;
                _selectedSessionIds.add(chat.id.toString());
              });
            }
          },
          // ===== NEW FEATURE END =====
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.blur_on, size: 80, color: _accentColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            "NO NEURAL RECORDS",
            style: TextStyle(
              color: _accentColor.withOpacity(0.3),
              letterSpacing: 4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 30),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _accentColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              provider.createNewChat();
              _navigateToChat(context);
            },
            child: Text(
              "INITIALIZE LINK",
              style: TextStyle(color: _accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
