import 'package:flutter/material.dart';
import 'package:migrated/widgets/floating_chat_head.dart';
import 'package:migrated/widgets/chat_screen.dart';
import 'package:migrated/models/chat_message.dart';

class FloatingChatWidget extends StatefulWidget {
  final String avatarImagePath;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;

  const FloatingChatWidget({
    Key? key,
    required this.avatarImagePath,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
  }) : super(key: key);

  @override
  State<FloatingChatWidget> createState() => FloatingChatWidgetState();
}

// Make the state class public so it can be referenced by the key
class FloatingChatWidgetState extends State<FloatingChatWidget> {
  bool _showChat = false;
  final GlobalKey<ChatScreenState> _chatScreenKey =
      GlobalKey<ChatScreenState>();

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
    });
  }

  // Public method to show the chat
  void showChat() {
    if (!_showChat) {
      setState(() {
        _showChat = true;
      });
    }
  }

  // Public method to add a user message
  void addUserMessage(String message) {
    if (_chatScreenKey.currentState != null) {
      _chatScreenKey.currentState!.addMessage(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // Public method to add an AI response
  void addAiResponse(String message) {
    if (_chatScreenKey.currentState != null) {
      _chatScreenKey.currentState!.addMessage(
        ChatMessage(
          text: message,
          isUser: false,
          timestamp: DateTime.now(),
          avatarImagePath: widget.avatarImagePath,
        ),
      );
    }
  }

  void _handleTapOutside(BuildContext context, TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);

    // Get screen size
    final size = MediaQuery.of(context).size;

    // Define chat screen boundaries
    final chatScreenRect = Rect.fromLTWH(
      size.width - 340, // 20px from right edge
      size.height - 580, // 100px from bottom
      320, // chat screen width
      480, // chat screen height
    );

    if (!chatScreenRect.contains(localOffset)) {
      _toggleChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap outside handler
        if (_showChat)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => _handleTapOutside(context, details),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // The floating chat head
        if (!_showChat)
          FloatingChatHead(
            avatarImagePath: widget.avatarImagePath,
            onTap: _toggleChat,
          ),

        // The chat screen
        if (_showChat)
          Positioned(
            right: 20,
            bottom: 100,
            child: ChatScreen(
              key: _chatScreenKey,
              avatarImagePath: widget.avatarImagePath,
              onClose: _toggleChat,
              onSendMessage: widget.onSendMessage,
              bookId: widget.bookId,
              bookTitle: widget.bookTitle,
            ),
          ),
      ],
    );
  }
}
