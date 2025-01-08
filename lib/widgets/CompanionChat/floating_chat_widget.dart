import 'package:flutter/material.dart';
import 'package:migrated/widgets/CompanionChat/chat_screen.dart';
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

  double _xPosition = 0;
  double _yPosition = 100;
  bool _isDragging = false;

  // Chat window size state
  double _chatWidth = 320;
  double _chatHeight = 480;
  bool _isResizing = false;

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

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _xPosition += details.delta.dx;
      _yPosition += details.delta.dy;

      // Keep the chat head within screen bounds
      _xPosition = _xPosition.clamp(0, MediaQuery.of(context).size.width - 60);
      _yPosition = _yPosition.clamp(0, MediaQuery.of(context).size.height - 60);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      _isDragging = false;

      // Snap to the nearest edge (left or right)
      if (_xPosition < screenWidth / 2) {
        // Snap to left edge
        _xPosition = 0;
      } else {
        // Snap to right edge
        _xPosition = screenWidth - 60;
      }

      // Ensure it stays within vertical bounds
      _yPosition = _yPosition.clamp(0, screenHeight - 60);
    });
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate chat position based on floating head position
    double chatY = _yPosition + 70; // 70 = chat head size + small gap

    // Ensure chat stays within screen bounds
    if (chatY + _chatHeight > screenSize.height - 20) {
      chatY = screenSize.height - _chatHeight - 20;
    }

    return Stack(
      children: [
        // Tap outside handler
        if (_showChat)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => _handleTapOutside(context, details),
              child: Container(color: Colors.transparent),
            ),
          ),

        // The chat screen
        if (_showChat)
          Positioned(
            right: 16,
            top: chatY,
            child: Stack(
              children: [
                Container(
                  width: _chatWidth,
                  height: _chatHeight,
                  child: ChatScreen(
                    avatarImagePath: widget.avatarImagePath,
                    onClose: () => setState(() => _showChat = false),
                    onSendMessage: widget.onSendMessage,
                    bookId: widget.bookId,
                    bookTitle: widget.bookTitle,
                    key: _chatScreenKey,
                  ),
                ),
                // Resize handle
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isResizing = true),
                    onPanUpdate: (details) {
                      setState(() {
                        _chatWidth = (_chatWidth + details.delta.dx)
                            .clamp(280.0, screenSize.width - 32);
                        _chatHeight = (_chatHeight + details.delta.dy)
                            .clamp(400.0, screenSize.height - 40);
                      });
                    },
                    onPanEnd: (_) => setState(() => _isResizing = false),
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.drag_handle,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // The floating chat head
        AnimatedPositioned(
          duration: Duration(milliseconds: _isDragging ? 0 : 300),
          curve: Curves.easeOutQuad,
          left: _xPosition,
          top: _yPosition,
          child: GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            onTap: () => setState(() => _showChat = !_showChat),
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  widget.avatarImagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
