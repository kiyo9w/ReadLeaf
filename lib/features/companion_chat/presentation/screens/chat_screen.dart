import 'package:flutter/material.dart';
import 'package:read_leaf/features/companion_chat/domain/models/chat_message.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/features/companion_chat/data/chat_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

class ChatScreen extends StatefulWidget {
  final AiCharacter character;
  final VoidCallback onClose;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;
  final String? selectedText;

  const ChatScreen({
    super.key,
    required this.character,
    required this.onClose,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
    this.selectedText,
  });

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  List<ChatMessage> _messages = [];
  final _chatService = GetIt.I<ChatService>();
  String? _currentCharacter;
  bool _isSyncing = false;
  bool _isLoading = true;

  // Animation controllers for message animations
  final Map<String, AnimationController> _messageAnimationControllers = {};

  @override
  void initState() {
    super.initState();
    _currentCharacter = widget.character.name;
    loadMessages();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.name != widget.character.name) {
      _currentCharacter = widget.character.name;
      setState(() {
        _isLoading = true;
        _messages = [];
      });
      loadMessages();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();

    // Dispose animation controllers
    for (final controller in _messageAnimationControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// Loads messages from storage and updates the UI.
  /// This is a public method that can be called to refresh the message list.
  Future<void> loadMessages() async {
    if (!mounted) return;

    try {
      final messages =
          await _chatService.getCharacterMessages(widget.character.name);

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Setup animations for new messages
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        final key =
            '${message.timestamp.millisecondsSinceEpoch}-${message.isUser}';

        if (!_messageAnimationControllers.containsKey(key)) {
          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 350),
          );

          _messageAnimationControllers[key] = controller;
          controller.forward();
        }
      }

      // Scroll to bottom after messages are loaded and rendered
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSubmitted(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    _messageController.clear();
    _focusNode.unfocus();

    widget.onSendMessage(trimmedText);

    // Wait for the message to be processed and stored
    await Future.delayed(const Duration(milliseconds: 100));
    await loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary;
    final backgroundColor = isDark ? const Color(0xFF251B2F) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
            ResponsiveConstants.isTablet(context) ? 28 : 24),
      ),
      child: Column(
        children: [
          // Chat header - enhanced with glass effect
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(
                  ResponsiveConstants.isTablet(context) ? 28 : 24),
              topRight: Radius.circular(
                  ResponsiveConstants.isTablet(context) ? 28 : 24),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
                  vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF352A3B).withOpacity(0.85)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                    topRight: Radius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? primaryColor.withOpacity(0.3)
                                : primaryColor.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: _buildAvatarImage(
                        widget.character.avatarImagePath,
                        radius:
                            ResponsiveConstants.isTablet(context) ? 24.0 : 20.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.character.name,
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConstants.getTitleFontSize(context),
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.character.trait,
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConstants.getBodyFontSize(context),
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: Icon(
                            Icons.close,
                            size: ResponsiveConstants.getIconSize(context),
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Chat messages
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
                vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
              ),
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                        strokeWidth: 3,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final key =
                            '${message.timestamp.millisecondsSinceEpoch}-${message.isUser}';
                        final controller = _messageAnimationControllers[key] ??
                            AnimationController(
                              vsync: this,
                              duration: Duration.zero,
                              value: 1.0,
                            );

                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(message.isUser ? 1.0 : -1.0, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: controller,
                            curve: Curves.easeOutCubic,
                          )),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: controller,
                              curve: Curves.easeOut,
                            ),
                            child: _buildMessageBubble(message),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Input field with enhanced styling
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(
                  ResponsiveConstants.isTablet(context) ? 28 : 24),
              bottomRight: Radius.circular(
                  ResponsiveConstants.isTablet(context) ? 28 : 24),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
                  vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF352A3B).withOpacity(0.85)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                    bottomRight: Radius.circular(
                        ResponsiveConstants.isTablet(context) ? 28 : 24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              ResponsiveConstants.isTablet(context) ? 20 : 16),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            fontSize:
                                ResponsiveConstants.getBodyFontSize(context),
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black45,
                              fontSize:
                                  ResponsiveConstants.getBodyFontSize(context),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveConstants.isTablet(context)
                                      ? 20
                                      : 16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveConstants.isTablet(context)
                                      ? 20
                                      : 16),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                width: 0.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveConstants.isTablet(context)
                                      ? 20
                                      : 16),
                              borderSide: BorderSide(
                                color: primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF251B2F) : Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: ResponsiveConstants.isTablet(context)
                                  ? 20
                                  : 16,
                              vertical: ResponsiveConstants.isTablet(context)
                                  ? 16
                                  : 12,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 5,
                          onSubmitted: _handleSubmitted,
                        ),
                      ),
                    ),
                    SizedBox(
                        width: ResponsiveConstants.isTablet(context) ? 16 : 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _handleSubmitted(_messageController.text),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.9),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send,
                            size: ResponsiveConstants.getIconSize(context),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveConstants.isTablet(context) ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? primaryColor.withOpacity(0.3)
                          : primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: _buildAvatarImage(
                  widget.character.avatarImagePath,
                  radius: ResponsiveConstants.isTablet(context) ? 18.0 : 14.0,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.isTablet(context) ? 20 : 16,
                vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
              ),
              decoration: BoxDecoration(
                color: message.isUser
                    ? (isDark
                        ? primaryColor.withOpacity(0.25)
                        : primaryColor.withOpacity(0.15))
                    : (isDark
                        ? const Color(0xFF251B2F).withOpacity(0.9)
                        : Colors.white.withOpacity(0.95)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                      ResponsiveConstants.isTablet(context) ? 24 : 20),
                  topRight: Radius.circular(
                      ResponsiveConstants.isTablet(context) ? 24 : 20),
                  bottomLeft: Radius.circular(message.isUser
                      ? (ResponsiveConstants.isTablet(context) ? 24 : 20)
                      : (ResponsiveConstants.isTablet(context) ? 8 : 4)),
                  bottomRight: Radius.circular(message.isUser
                      ? (ResponsiveConstants.isTablet(context) ? 8 : 4)
                      : (ResponsiveConstants.isTablet(context) ? 24 : 20)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -3,
                  ),
                ],
                border: Border.all(
                  color: message.isUser
                      ? (isDark
                          ? primaryColor.withOpacity(0.2)
                          : primaryColor.withOpacity(0.15))
                      : Colors.transparent,
                  width: 0.5,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: ResponsiveConstants.getBodyFontSize(context),
                  color: message.isUser
                      ? (isDark
                          ? Colors.white.withOpacity(0.95)
                          : Colors.black87)
                      : (isDark
                          ? Colors.white.withOpacity(0.95)
                          : Colors.black87),
                ),
              ),
            ),
          ),
          if (message.isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: message.isSynced
                      ? Colors.green.shade400
                      : Colors.grey.shade400,
                ),
                child: message.isSynced
                    ? Icon(
                        Icons.check,
                        size: 8,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // Shared method to build avatar images with caching
  Widget _buildAvatarImage(String imagePath, {required double radius}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Create the avatar widget
    Widget buildAvatarContent() {
      // For network images
      if (imagePath.startsWith('http') ||
          imagePath.startsWith('https') ||
          imagePath.contains('avatars.charhub.io')) {
        return CachedNetworkImage(
          imageUrl: imagePath,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          errorWidget: (context, url, error) {
            debugPrint('Error loading chat avatar: $url - $error');
            return Container(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Icon(
                Icons.person,
                size: radius * 0.9,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            );
          },
          fadeInDuration: const Duration(milliseconds: 0),
          memCacheHeight: (radius * 3).toInt(),
          memCacheWidth: (radius * 3).toInt(),
          cacheKey: 'chat_msg_avatar_$imagePath',
          useOldImageOnUrlChange: true,
        );
      }

      // For asset images
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheHeight: (radius * 3).toInt(),
        cacheWidth: (radius * 3).toInt(),
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading avatar asset in chat: $error');
          return Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: Icon(
              Icons.person,
              size: radius * 0.9,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          );
        },
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: buildAvatarContent(),
        ),
      ),
    );
  }
}
