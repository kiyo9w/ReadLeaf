import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:read_leaf/models/chat_message.dart';
import 'package:read_leaf/services/chat_service.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';

// NOTE: This service is currently not in use. The functionality has been migrated to GeminiService.
// Keeping this code for reference in case we need to reimplement RAG with a backend service.
class RagService {
  static final RagService _instance = RagService._internal();
  // final ChatService _chatService = getIt<ChatService>();
  // final AiCharacterService _characterService = getIt<AiCharacterService>();
  // static const int _maxConversationHistory = 5;

  // Backend URL, injected via dependency injection (e.g., "http://localhost:8000")
  // final String _backendUrl = getIt<String>(instanceName: 'backendUrl');

  RagService._internal();
  factory RagService() => _instance;

  /// Uploads a PDF file to the backend /upload-pdf endpoint.
  /// Returns a message indicating success or throws an exception on failure.
  Future<String> uploadPdf(File file) async {
    throw UnimplementedError(
        'RAG service is currently disabled. Using GeminiService instead.');
    /*
    try {
      final url = Uri.parse(_backendUrl).resolve('/upload-pdf');
      print('Uploading PDF to backend: ${file.path}');

      final request = http.MultipartRequest("POST", url);
      final multipartFile =
          await http.MultipartFile.fromPath("file", file.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] as String;
      } else {
        throw Exception("Error uploading PDF: ${response.body}");
      }
    } catch (e) {
      print('Error uploading PDF: $e');
      throw Exception('Failed to upload PDF: $e');
    }
    */
  }

  /// Builds conversation context from the latest chat messages for the given book.
  Future<String> buildConversationContext(String bookId) async {
    throw UnimplementedError(
        'RAG service is currently disabled. Using GeminiService instead.');
    /*
    try {
      final characterName =
          _characterService.getSelectedCharacter()?.name ?? 'Default';
      // Use getBookMessages (which should be defined in ChatService)
      final List<ChatMessage> messages =
          await _chatService.getBookMessages(characterName, bookId);
      if (messages.isEmpty) return '';
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
    */
  }

  /// Builds a complete prompt context by merging conversation history,
  /// any selected text, and the user's query (custom prompt).
  Future<String> buildPromptContext({
    required String bookId,
    String? selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    String? customPrompt,
  }) async {
    throw UnimplementedError(
        'RAG service is currently disabled. Using GeminiService instead.');
    /*
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
    */
  }

  /// Calls the backend /query endpoint.
  /// It constructs a nested payload with extra template variables under "doc_to_text",
  /// so that the backend's DocToText component can merge the document context.
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
    throw UnimplementedError(
        'RAG service is currently disabled. Using GeminiService instead.');
    /*
    // Construct payload with the expected flat structure.
    final Map<String, dynamic> payload = {
      "user_query": userQuery,
      "selected_text": selectedText ?? "",
      "book_title": bookTitle,
      "page_number": currentPage,
      "total_pages": totalPages,
      "ai_name": aiName,
      "ai_personality": aiPersonality,
    };

    final url = Uri.parse(_backendUrl).resolve('/query');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    print("Response status code: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'] as String;
    } else {
      throw Exception("Error querying backend: ${response.body}");
    }
    */
  }
}
