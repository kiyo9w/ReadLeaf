import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:read_leaf/features/companion_chat/presentation/screens/chat_screen.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

class FloatingChatWidget extends StatefulWidget {
  final AiCharacter character;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;
  final double keyboardHeight;
  final bool isKeyboardVisible;

  const FloatingChatWidget({
    super.key,
    required this.character,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
    required this.keyboardHeight,
    required this.isKeyboardVisible,
  });

  @override
  State<FloatingChatWidget> createState() => FloatingChatWidgetState();
}

// Make the state class public so it can be referenced by the key
class FloatingChatWidgetState extends State<FloatingChatWidget>
    with SingleTickerProviderStateMixin {
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

  // Animation controller for opening/closing effects
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

      // Start opening animation
      _animationController.forward(from: 0.0);

      // Validate position with chat widget in consideration
      final validY = _getValidYPosition(_yPosition, context);
      if (validY != _yPosition) {
        _animateToPosition(_xPosition, validY);
      }
    } else {
      // Start closing animation
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showChat = false;
          });
        }
      });

      // Animate to original position
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // Calculate chat container height
    double adjustedChatHeight = _chatHeight;
    if (isKeyboardVisible) {
      // When keyboard is visible, we want to ensure the chat container
      // stays within the visible area while keeping the input field visible
      final maxVisibleHeight = availableHeight - chatY;
      if (maxVisibleHeight < _chatHeight) {
        // Try to move the chat head up first
        final potentialNewY =
            availableHeight - _chatHeight - _chatHeadSize - _minSpacing;
        if (potentialNewY >= _topPadding) {
          _yPosition = potentialNewY;
          chatY = _yPosition + _chatHeadSize + _minSpacing;
          adjustedChatHeight = _chatHeight;
        } else {
          // If we can't move up enough, adjust the height
          adjustedChatHeight = math.max(
              ResponsiveConstants.isTablet(context) ? 500.0 : 400.0,
              maxVisibleHeight);
        }
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: _xPosition < screenSize.width / 2
                    ? Alignment.topLeft
                    : Alignment.topRight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: -5,
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
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
                          // Resize handle at the bottom right corner
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onPanStart: (details) {
                                setState(() {
                                  _isResizing = true;
                                });
                              },
                              onPanUpdate: _handleResize,
                              onPanEnd: (details) {
                                setState(() {
                                  _isResizing = false;
                                });
                              },
                              child: Container(
                                height: 36,
                                width: 36,
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.unfold_more,
                                  size: 24,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white60
                                      : Colors.black45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: _chatHeadSize,
              height: _chatHeadSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF352A3B)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: ResponsiveConstants.isTablet(context) ? 16 : 12,
                    offset: const Offset(0, 4),
                    spreadRadius: _showChat ? 0 : -2,
                  ),
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                    blurRadius: ResponsiveConstants.isTablet(context) ? 16 : 12,
                    offset: const Offset(0, 0),
                    spreadRadius: _showChat ? 2 : 0,
                  ),
                ],
                border: Border.all(
                  color: _showChat
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: EdgeInsets.all(_showChat ? 2 : 0),
                  child: _buildAvatar(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build avatar image with proper caching
  Widget _buildAvatar() {
    final imagePath = widget.character.avatarImagePath;

    // Handle network images
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading avatar in chat head: $url - $error');
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person,
              size: 30,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
        fadeInDuration: const Duration(
            milliseconds: 0), // No fade animation to prevent flicker
        memCacheHeight: 150, // Sufficient for chat avatar
        memCacheWidth: 150,
        cacheKey:
            'chat_avatar_${widget.character.name}', // Use stable cache key
        useOldImageOnUrlChange:
            true, // Keep showing old image while new one loads
      );
    }

    // Handle asset images
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      cacheHeight: 150,
      cacheWidth: 150,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading avatar asset: $error');
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: 30,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
