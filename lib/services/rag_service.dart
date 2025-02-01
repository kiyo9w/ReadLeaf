import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:migrated/models/chat_message.dart';
import 'package:migrated/services/chat_service.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';

class RagService {
  static final RagService _instance = RagService._internal();
  final ChatService _chatService = getIt<ChatService>();
  final AiCharacterService _characterService = getIt<AiCharacterService>();
  static const int _maxConversationHistory = 5;

  // The backend URL should be registered in GetIt (instanceName: 'backendUrl')
  final String _backendUrl = getIt<String>(instanceName: 'backendUrl');

  RagService._internal();

  factory RagService() => _instance;

  /// Builds a conversation context for a given book by retrieving messages
  /// from the ChatService for the selected character and filtering by book ID.
  Future<String> buildConversationContext(String bookId) async {
    try {
      // Use the selected character's name (or a default)
      final characterName =
          _characterService.getSelectedCharacter()?.name ?? 'Default';
      // Use getBookMessages (which is defined in your ChatService)
      final messages =
          await _chatService.getBookMessages(characterName, bookId);
      if (messages.isEmpty) return '';

      // Only use the last _maxConversationHistory messages for context.
      final recentMessages = messages.length <= _maxConversationHistory
          ? messages
          : messages.sublist(messages.length - _maxConversationHistory);
      final conversationContext = recentMessages.map((msg) {
        final role = msg.isUser ? 'User' : 'Assistant';
        return '$role: ${msg.text}';
      }).join('\n');
      return 'Previous conversation context:\n$conversationContext';
    } catch (e) {
      print('Error building conversation context: $e');
      return '';
    }
  }

  /// Builds the complete prompt context by combining conversation history,
  /// any selected text, and a custom prompt.
  Future<String> buildPromptContext({
    required String bookId,
    String? selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    String? customPrompt,
  }) async {
    final conversationContext = await buildConversationContext(bookId);
    final buffer = StringBuffer();

    if (conversationContext.isNotEmpty) {
      buffer.writeln(conversationContext);
      buffer.writeln();
    }

    if (selectedText != null && selectedText.isNotEmpty) {
      buffer.writeln(
          'Current text selection from "$bookTitle" (page $currentPage of $totalPages):');
      buffer.writeln(selectedText);
      buffer.writeln();
    }

    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln('User question:');
      buffer.writeln(customPrompt);
    }

    return buffer.toString().trim();
  }

  /// Calls the backend /query endpoint.
  /// It sends a JSON payload with the conversation context (built from local chat history)
  /// along with book information and the AI character details.
  Future<String> query({
    required String bookId,
    String? selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required String aiName,
    required String aiPersonality,
    required String userQuery,
  }) async {
    // Build the prompt context using local conversation history and the user's custom prompt.
    final promptContext = await buildPromptContext(
      bookId: bookId,
      selectedText: selectedText,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      customPrompt: userQuery,
    );

    // Construct the JSON payload expected by the backend.
    final Map<String, dynamic> payload = {
      'user_query': promptContext,
      'selected_text': selectedText ?? '',
      'book_title': bookTitle,
      'page_number': currentPage,
      'total_pages': totalPages,
      'ai_name': aiName,
      'ai_personality': aiPersonality,
    };

    // Call the backend's /query endpoint.
    final url = Uri.parse(_backendUrl).resolve('/query');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'] as String;
    } else {
      throw Exception("Error querying backend: ${response.body}");
    }
  }
}