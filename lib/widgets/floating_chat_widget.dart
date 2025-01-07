import 'package:flutter/material.dart';
import 'package:migrated/widgets/floating_chat_head.dart';
import 'package:migrated/widgets/chat_screen.dart';

class FloatingChatWidget extends StatefulWidget {
  final String avatarImagePath;
  final Function(String) onSendMessage;

  const FloatingChatWidget({
    Key? key,
    required this.avatarImagePath,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  State<FloatingChatWidget> createState() => _FloatingChatWidgetState();
}

class _FloatingChatWidgetState extends State<FloatingChatWidget> {
  bool _showChat = false;

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
    });
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
              avatarImagePath: widget.avatarImagePath,
              onClose: _toggleChat,
              onSendMessage: widget.onSendMessage,
            ),
          ),
      ],
    );
  }
}
