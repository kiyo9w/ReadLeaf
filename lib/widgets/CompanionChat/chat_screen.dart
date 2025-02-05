import 'package:flutter/material.dart';
import 'package:read_leaf/models/chat_message.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/services/chat_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/constants/responsive_constants.dart';

class ChatScreen extends StatefulWidget {
  final AiCharacter character;
  final VoidCallback onClose;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;

  const ChatScreen({
    Key? key,
    required this.character,
    required this.onClose,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  List<ChatMessage> _messages = [];
  final _chatService = GetIt.I<ChatService>();
  String? _currentCharacter;

  @override
  void initState() {
    super.initState();
    _currentCharacter = widget.character.name;
    _loadMessages();
    // Add post-frame callback to scroll to bottom after initial render
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If character changed, reload messages
    if (oldWidget.character.name != widget.character.name) {
      print(
          'Character changed from ${oldWidget.character.name} to ${widget.character.name}');
      _currentCharacter = widget.character.name;
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.bookId != null) {
      final messages = await _chatService.getBookMessages(
        widget.character.name,
        widget.bookId,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
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

  Future<void> addMessage(ChatMessage message) async {
    print('Adding message for character: ${message.characterName}');
    // Verify character name matches current character
    if (message.characterName != widget.character.name) {
      print(
          'Warning: Message character (${message.characterName}) does not match current character (${widget.character.name})');
      return;
    }

    // Add message to UI immediately
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    // Save to storage asynchronously
    await _chatService.addMessage(message);
    await _chatService.debugPrintBoxes();
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final message = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      characterName: widget.character.name,
      bookId: widget.bookId,
    );

    setState(() {
      _messages.add(message);
    });

    _messageController.clear();
    _scrollToBottom();

    // Save the message and get AI response
    if (widget.bookId != null) {
      await _chatService.addMessage(message);
    }
    widget.onSendMessage?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF251B2F) : Colors.white,
        borderRadius: BorderRadius.circular(
            ResponsiveConstants.isTablet(context) ? 24 : 16),
        image: DecorationImage(
          image: AssetImage(
            isDark
                ? 'assets/images/chat/chat_bg_pattern_dark.png'
                : 'assets/images/chat/chat_bg_pattern.png',
          ),
          fit: BoxFit.cover,
          opacity: isDark ? 0.05 : 0.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: ResponsiveConstants.isTablet(context) ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
              vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF352A3B).withOpacity(0.95)
                  : const Color(0xFFF8F1F1).withOpacity(0.95),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(
                    ResponsiveConstants.isTablet(context) ? 24 : 16),
                topRight: Radius.circular(
                    ResponsiveConstants.isTablet(context) ? 24 : 16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: ResponsiveConstants.isTablet(context) ? 24 : 20,
                  backgroundImage: AssetImage(widget.character.imagePath),
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
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: ResponsiveConstants.getIconSize(context),
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
                vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
          ),

          // Input field
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
              vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF352A3B) : const Color(0xFFF8F1F1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                    ResponsiveConstants.isTablet(context) ? 24 : 16),
                bottomRight: Radius.circular(
                    ResponsiveConstants.isTablet(context) ? 24 : 16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: TextStyle(
                      fontSize: ResponsiveConstants.getBodyFontSize(context),
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black45,
                        fontSize: ResponsiveConstants.getBodyFontSize(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            ResponsiveConstants.isTablet(context) ? 16 : 12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF251B2F) : Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveConstants.isTablet(context) ? 20 : 16,
                        vertical:
                            ResponsiveConstants.isTablet(context) ? 16 : 12,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                SizedBox(
                    width: ResponsiveConstants.isTablet(context) ? 16 : 12),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    size: ResponsiveConstants.getIconSize(context),
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => _handleSubmitted(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveConstants.isTablet(context) ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: ResponsiveConstants.isTablet(context) ? 20 : 16,
                backgroundImage: AssetImage(widget.character.imagePath),
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
                        ? const Color(0xFF352A3B).withOpacity(0.95)
                        : Colors.blue.shade50)
                    : (isDark
                        ? const Color(0xFF251B2F).withOpacity(0.95)
                        : Colors.white.withOpacity(0.95)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(
                      ResponsiveConstants.isTablet(context) ? 20 : 16),
                  topRight: Radius.circular(
                      ResponsiveConstants.isTablet(context) ? 20 : 16),
                  bottomLeft: Radius.circular(message.isUser
                      ? 20
                      : (ResponsiveConstants.isTablet(context) ? 8 : 4)),
                  bottomRight: Radius.circular(message.isUser
                      ? (ResponsiveConstants.isTablet(context) ? 8 : 4)
                      : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: ResponsiveConstants.isTablet(context) ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: ResponsiveConstants.getBodyFontSize(context),
                  color:
                      isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseText(String text) {
    final List<TextSpan> spans = [];
    final RegExp emotePattern = RegExp(r'\*(.*?)\*');
    final RegExp importedTextPattern = RegExp(r'""".*?"""');

    int currentPosition = 0;

    while (currentPosition < text.length) {
      // Try to find the next emote or imported text
      final emoteMatch =
          emotePattern.firstMatch(text.substring(currentPosition));
      final importedMatch =
          importedTextPattern.firstMatch(text.substring(currentPosition));

      // Determine which pattern comes first
      final emoteIndex = emoteMatch?.start ?? text.length;
      final importedIndex = importedMatch?.start ?? text.length;

      if (emoteIndex < importedIndex) {
        // Add text before the emote
        if (emoteIndex > 0) {
          spans.add(TextSpan(
            text: text.substring(currentPosition, currentPosition + emoteIndex),
          ));
        }
        // Add the emote with special styling
        spans.add(TextSpan(
          text: emoteMatch![1],
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ));
        currentPosition += emoteMatch.end;
      } else if (importedIndex < text.length) {
        // Add text before the imported text
        if (importedIndex > 0) {
          spans.add(TextSpan(
            text: text.substring(
                currentPosition, currentPosition + importedIndex),
          ));
        }
        // Add the entire imported text block including quotes with special styling
        spans.add(TextSpan(
          text: importedMatch![
              0], // Use [0] to get the entire match including quotes
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ));
        currentPosition += importedMatch.end;
      } else {
        // Add the remaining text
        spans.add(TextSpan(
          text: text.substring(currentPosition),
        ));
        break;
      }
    }

    return spans;
  }
}
