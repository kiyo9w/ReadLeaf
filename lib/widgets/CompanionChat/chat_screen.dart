import 'package:flutter/material.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:migrated/services/chat_service.dart';
import 'package:get_it/get_it.dart';

class ChatScreen extends StatefulWidget {
  final String avatarImagePath;
  final VoidCallback onClose;
  final Function(String) onSendMessage;
  final String bookId;
  final String bookTitle;

  const ChatScreen({
    Key? key,
    required this.avatarImagePath,
    required this.onClose,
    required this.onSendMessage,
    required this.bookId,
    required this.bookTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = GetIt.I<ChatService>();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Add post-frame callback to scroll to bottom after initial render
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _chatService.getMessages(widget.bookId);
    setState(() {
      _messages = messages;
    });
    // Add post-frame callback to scroll to bottom after messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> addMessage(ChatMessage message) async {
    // Add message to UI immediately
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    // Save to storage asynchronously
    await _chatService.addMessage(widget.bookId, message);
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    _textController.clear();

    final message = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    // Save the message asynchronously
    await _chatService.addMessage(widget.bookId, message);

    // Call the callback to get AI response
    widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: const AssetImage('assets/images/chat_bg_pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: Image.asset(
                        widget.avatarImagePath,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Amelia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (widget.bookTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.bookTitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: () => _handleSubmitted(_textController.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    String displayText = message.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser && message.avatarImagePath != null) ...[
            ClipOval(
              child: Image.asset(
                message.avatarImagePath!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // if (message.isUser) ...[
          //   ClipOval(
          //     child: Image.asset(
          //       'user-default-logo.png',
          //       width: 32,
          //       height: 32,
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          //   const SizedBox(width: 8),
          // ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFFE3F2FD) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      children: _parseText(displayText),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser)
            const SizedBox(width: 40), // Space for avatar symmetry
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
