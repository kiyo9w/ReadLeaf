// import 'package:migrated/models/chat_message.dart';
// import 'package:migrated/services/chat_service.dart';
// import 'package:migrated/depeninject/injection.dart';

// class RagService {
//   static final RagService _instance = RagService._internal();
//   final ChatService _chatService;
//   static const int _maxConversationHistory = 5;

//   RagService._internal() : _chatService = getIt<ChatService>();

//   factory RagService() {
//     return _instance;
//   }

//   Future<String> buildConversationContext(String bookId) async {
//     try {
//       final messages = await _chatService.getMessages(bookId);
//       if (messages.isEmpty) return '';

//       // Get the last 5 messages
//       final recentMessages = messages.length <= _maxConversationHistory
//           ? messages
//           : messages.sublist(messages.length - _maxConversationHistory);

//       // Format conversation history
//       final conversationContext = recentMessages.map((msg) {
//         final role = msg.isUser ? 'User' : 'Assistant';
//         return '$role: ${msg.text}';
//       }).join('\n');

//       return '''
// Previous conversation context:
// $conversationContext
// ''';
//     } catch (e) {
//       print('Error building conversation context: $e');
//       return '';
//     }
//   }

//   Future<String> buildPromptContext({
//     required String bookId,
//     String? selectedText,
//     required String bookTitle,
//     required int currentPage,
//     required int totalPages,
//     String? customPrompt,
//   }) async {
//     final conversationContext = await buildConversationContext(bookId);

//     // Build the complete context
//     final contextBuilder = StringBuffer();

//     if (conversationContext.isNotEmpty) {
//       contextBuilder.writeln(conversationContext);
//       contextBuilder.writeln();
//     }

//     if (selectedText != null && selectedText.isNotEmpty) {
//       contextBuilder.writeln(
//           'Current text selection from $bookTitle (page $currentPage of $totalPages):');
//       contextBuilder.writeln(selectedText);
//       contextBuilder.writeln();
//     }

//     if (customPrompt != null && customPrompt.isNotEmpty) {
//       contextBuilder.writeln('User question:');
//       contextBuilder.writeln(customPrompt);
//     }

//     return contextBuilder.toString().trim();
//   }
// }
