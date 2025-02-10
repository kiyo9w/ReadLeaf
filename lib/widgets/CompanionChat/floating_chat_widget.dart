import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:read_leaf/widgets/CompanionChat/chat_screen.dart';
import 'package:read_leaf/models/chat_message.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/constants/responsive_constants.dart';

class FloatingChatWidget extends StatefulWidget {
  final AiCharacter character;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;
  final double keyboardHeight;
  final bool isKeyboardVisible;

  const FloatingChatWidget({
    Key? key,
    required this.character,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
    required this.keyboardHeight,
    required this.isKeyboardVisible,
  }) : super(key: key);

  @override
  State<FloatingChatWidget> createState() => FloatingChatWidgetState();
}

// Make the state class public so it can be referenced by the key
class FloatingChatWidgetState extends State<FloatingChatWidget> {
  bool _showChat = false;
  final GlobalKey<ChatScreenState> _chatScreenKey =
      GlobalKey<ChatScreenState>();
  String? _currentCharacter;

  // Position state
  double _xPosition = 0;
  double _yPosition = 100;
  double? _originalX;
  double? _originalY;
  bool _isDragging = false;
  bool _isAnimating = false;

  // Chat window size state
  double _chatWidth = 320;
  double _chatHeight = 480;
  bool _isResizing = false;

  // Constants for positioning
  double get _chatHeadSize =>
      ResponsiveConstants.getFloatingChatHeadSize(context);
  double get _minSpacing => ResponsiveConstants.isTablet(context) ? 24.0 : 16.0;
  double get _bottomPadding =>
      ResponsiveConstants.isTablet(context) ? 32.0 : 16.0;
  double get _topPadding => ResponsiveConstants.isTablet(context) ? 32.0 : 16.0;

  @override
  void initState() {
    super.initState();
    _currentCharacter = widget.character.name;

    // Set initial position to be valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _yPosition = _getValidYPosition(_yPosition, context);
        });
      }
    });
  }

  @override
  void didUpdateWidget(FloatingChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.name != widget.character.name) {
      setState(() {
        _currentCharacter = widget.character.name;
      });
    }
  }

  void _toggleChat() {
    if (!_showChat) {
      // Store original position before opening chat
      _originalX = _xPosition;
      _originalY = _yPosition;

      // First set showChat to true so position validation considers chat widget
      setState(() {
        _showChat = true;
      });

      // Validate position with chat widget in consideration
      final validY = _getValidYPosition(_yPosition, context);
      if (validY != _yPosition) {
        _animateToPosition(_xPosition, validY);
      }
    } else {
      // When closing, first hide the chat
      if (mounted) {
        setState(() {
          _showChat = false;
        });
      }
      // Then animate to original position
      if (_originalX != null && _originalY != null) {
        _animateToPosition(_originalX!, _originalY!);
      }
    }
  }

  void _animateToPosition(double targetX, double targetY) {
    setState(() {
      _isAnimating = true;
      _xPosition = targetX;
      _yPosition = targetY;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  double _getValidYPosition(double y, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final keyboardHeight = bottomPadding > 0 ? bottomPadding : 0;

    double minY = _topPadding;
    double maxY =
        screenSize.height - _chatHeadSize - keyboardHeight - _bottomPadding;

    if (_showChat) {
      // Calculate maximum chat height based on screen constraints
      final maxChatHeight = screenSize.height - keyboardHeight - _bottomPadding;

      // Adjust chat height if it's too big
      if (_chatHeight > maxChatHeight - _topPadding - _minSpacing * 2) {
        setState(() {
          _chatHeight = maxChatHeight - _topPadding - _minSpacing * 2;
        });
      }

      // When chat is open, ensure there's enough space for the chat widget below
      maxY = screenSize.height -
          _chatHeight -
          _chatHeadSize -
          _minSpacing -
          _bottomPadding;
    }

    return y.clamp(minY, maxY);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _xPosition = (_xPosition + details.delta.dx)
          .clamp(0, screenSize.width - _chatHeadSize);
      _yPosition = _getValidYPosition(_yPosition + details.delta.dy, context);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      _isDragging = false;

      // Snap X to nearest edge
      if (_xPosition < screenWidth / 2) {
        _xPosition = 0;
      } else {
        _xPosition = screenWidth - _chatHeadSize;
      }

      // Ensure Y position is valid and animate to it if needed
      final validY = _getValidYPosition(_yPosition, context);
      if (validY != _yPosition) {
        _animateToPosition(_xPosition, validY);
      } else {
        _yPosition = validY;
      }
    });
  }

  void showChat() {
    if (!_showChat) {
      _toggleChat();
    }
  }

  // Public method to add a user message
  void addUserMessage(String message) {
    print('Adding user message for character: ${widget.character.name}');
    if (_chatScreenKey.currentState != null) {
      _chatScreenKey.currentState!.loadMessages(); // Use public method
    }
  }

  // Public method to add an AI response
  void addAiResponse(String message) {
    print('Adding AI response for character: ${widget.character.name}');
    if (_chatScreenKey.currentState != null) {
      _chatScreenKey.currentState!.loadMessages(); // Use public method
    }
  }

  void _handleTapOutside(BuildContext context, TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = box.globalToLocal(details.globalPosition);

    // Get screen size
    final size = MediaQuery.of(context).size;

    // Calculate chat Y position
    double chatY = _yPosition + 70;
    if (chatY + _chatHeight > size.height - 20) {
      chatY = size.height - _chatHeight - 20;
    }

    // Calculate chat X position based on floating head position
    double chatX = _xPosition < size.width / 2
        ? 16 // Left aligned
        : size.width - _chatWidth - 16; // Right aligned

    // Define chat screen boundaries using actual position and size
    final chatScreenRect = Rect.fromLTWH(
      chatX,
      chatY,
      _chatWidth,
      _chatHeight,
    );

    if (!chatScreenRect.contains(localOffset)) {
      _toggleChat();
    }
  }

  // Add these getter methods for cleaner constraint calculations
  double _getMaxChatHeight(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenSize.height - keyboardHeight - _bottomPadding;

    // Calculate maximum height based on space below chat head
    final spaceBelow =
        availableHeight - (_yPosition + _chatHeadSize + _minSpacing);
    return spaceBelow.clamp(
        ResponsiveConstants.isTablet(context) ? 500.0 : 400.0, double.infinity);
  }

  double _getMaxChatWidth(BuildContext context) {
    return ResponsiveConstants.getMaxChatWidth(context);
  }

  void _handleResize(DragUpdateDetails details) {
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = _getMaxChatWidth(context);
    final maxHeight = _getMaxChatHeight(context);
    final minWidth = ResponsiveConstants.getMinChatWidth(context);

    setState(() {
      // Handle horizontal resize
      final horizontalDelta = _xPosition < screenSize.width / 2
          ? details.delta.dx
          : -details.delta.dx;

      double newWidth =
          (_chatWidth + horizontalDelta).clamp(minWidth, maxWidth);
      if (newWidth != _chatWidth) {
        _chatWidth = newWidth;
      }

      // Only allow downward resizing
      if (details.delta.dy > 0) {
        // Expanding downward
        double newHeight = (_chatHeight + details.delta.dy).clamp(
            ResponsiveConstants.isTablet(context) ? 500.0 : 400.0, maxHeight);
        if (newHeight != _chatHeight) {
          _chatHeight = newHeight;
        }
      } else if (details.delta.dy < 0) {
        // Allow shrinking upward but not beyond minimum height
        double newHeight = (_chatHeight + details.delta.dy).clamp(
            ResponsiveConstants.isTablet(context) ? 500.0 : 400.0, _chatHeight);
        _chatHeight = newHeight;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isKeyboardVisible = widget.isKeyboardVisible;
    final keyboardHeight = widget.keyboardHeight;

    // Calculate chat position based on chat head position
    double chatY = _yPosition + _chatHeadSize + _minSpacing;

    // Calculate maximum available height considering keyboard
    final availableHeight = screenSize.height -
        _bottomPadding -
        (isKeyboardVisible ? keyboardHeight : 0);

    // Ensure chat head doesn't go too high when keyboard is visible
    if (isKeyboardVisible && _yPosition < _topPadding) {
      _yPosition = _topPadding;
    }

    // Ensure chat stays within screen bounds
    if (isKeyboardVisible) {
      if (chatY + _chatHeight > availableHeight) {
        // First try to move chat head up if possible
        double newHeadY =
            availableHeight - _chatHeight - _chatHeadSize - _minSpacing;
        if (newHeadY >= _topPadding) {
          _yPosition = newHeadY;
          chatY = _yPosition + _chatHeadSize + _minSpacing;
        } else {
          // If can't move head up, adjust chat height
          chatY = _topPadding + _chatHeadSize + _minSpacing;
          _chatHeight = math.max(
              ResponsiveConstants.isTablet(context) ? 500.0 : 400.0,
              availableHeight - chatY);
        }
      }
    }

    // Adjust chat height when keyboard is visible
    double adjustedChatHeight = _chatHeight;
    if (isKeyboardVisible) {
      final maxHeight = availableHeight - chatY;
      // Ensure we don't go below minimum height
      if (maxHeight < 400.0) {
        // Move chat head up if possible
        double newHeadY = availableHeight - 400.0 - _chatHeadSize - _minSpacing;
        if (newHeadY >= _topPadding) {
          _yPosition = newHeadY;
          chatY = _yPosition + _chatHeadSize + _minSpacing;
          adjustedChatHeight = 400.0;
        } else {
          // If we can't move up, use maximum available space
          adjustedChatHeight = math.max(400.0, maxHeight);
        }
      } else {
        adjustedChatHeight = math.min(_chatHeight, maxHeight);
      }
    }

    return Stack(
      children: [
        if (_showChat)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => _handleTapOutside(context, details),
              child: Container(color: Colors.transparent),
            ),
          ),
        if (_showChat)
          Positioned(
            right: _xPosition < screenSize.width / 2 ? null : 16,
            left: _xPosition < screenSize.width / 2 ? 16 : null,
            top: chatY,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _chatWidth,
                  height: adjustedChatHeight,
                  child: ChatScreen(
                    character: widget.character,
                    onClose: _toggleChat,
                    onSendMessage: widget.onSendMessage,
                    bookId: widget.bookId,
                    bookTitle: widget.bookTitle,
                    key: _chatScreenKey,
                  ),
                ),
                // Resize handle
                if (!isKeyboardVisible)
                  Positioned(
                    left: _xPosition < screenSize.width / 2 ? null : 0,
                    right: _xPosition < screenSize.width / 2 ? 0 : null,
                    bottom: 0,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _isResizing = true),
                      onPanUpdate: _handleResize,
                      onPanEnd: (_) => setState(() => _isResizing = false),
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.open_with,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        AnimatedPositioned(
          duration: Duration(milliseconds: _isDragging ? 0 : 300),
          curve: Curves.easeOutQuad,
          left: _xPosition,
          top: _yPosition,
          child: GestureDetector(
            onPanStart: (details) => setState(() => _isDragging = true),
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            onTap: _toggleChat,
            child: Container(
              width: _chatHeadSize,
              height: _chatHeadSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF352A3B)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: ResponsiveConstants.isTablet(context) ? 16 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  widget.character.avatarImagePath,
                  width: _chatHeadSize,
                  height: _chatHeadSize,
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
