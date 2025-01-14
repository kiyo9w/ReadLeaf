import 'package:flutter/material.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/services/chat_service.dart';
import 'package:get_it/get_it.dart';

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
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = GetIt.I<ChatService>();
  List<ChatMessage> _messages = [];
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
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    print('Loading messages for character: ${widget.character.name}');

    // Load book-specific messages first
    final bookMessages = await _chatService.getBookMessages(
      widget.character.name,
      widget.bookId,
    );

    // If this is a new book conversation, also get the last few general messages for context
    if (bookMessages.isEmpty) {
      final lastMessages =
          await _chatService.getLastNMessages(widget.character.name, n: 5);
      if (mounted) {
        setState(() {
          _messages = lastMessages;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _messages = bookMessages;
        });
      }
    }

    // Debug: Print current message state
    print('Loaded ${_messages.length} messages for ${widget.character.name}');
    await _chatService.debugPrintBoxes();

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
    if (text.isEmpty) return;

    _textController.clear();

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
    _scrollToBottom();

    // Save the message asynchronously
    await _chatService.addMessage(message);

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
          image: const AssetImage('assets/images/chat/chat_bg_pattern.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage(widget.character.imagePath),
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.character.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
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
