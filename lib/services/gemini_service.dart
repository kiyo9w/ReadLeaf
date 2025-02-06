import 'dart:developer';
import 'dart:math' as math;
import 'dart:collection';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/services/chat_service.dart';
import 'package:read_leaf/models/chat_message.dart';

class ConversationEntry {
  final String userInput;
  final String aiResponse;
  ConversationEntry(this.userInput, this.aiResponse);
}

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  late final GenerativeModel _model;
  AiCharacterService? _characterService;
  ChatService? _chatService;
  bool _isInitialized = false;
  static const int maxConversations = 5;

  // Store conversations per book
  final Map<String, Queue<ConversationEntry>> _conversationHistory = {};

  // Private constructor
  GeminiService._internal();

  // Factory constructor for GetIt
  factory GeminiService() {
    return _instance;
  }

  AiCharacterService get characterService {
    _characterService ??= getIt<AiCharacterService>();
    return _characterService!;
  }

  ChatService get chatService {
    _chatService ??= getIt<ChatService>();
    return _chatService!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        log('Error: GEMINI_API_KEY not set in .env file');
        return;
      }

      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topP: 0.8,
          topK: 40,
          maxOutputTokens: 20480,
        ),
      );
      _isInitialized = true;
    } catch (e) {
      log('Error initializing Gemini service: $e');
    }
  }

  /// Builds conversation context from the latest chat messages for the given book.
  Future<String> buildConversationContext(String bookId) async {
    try {
      final characterName =
          characterService.getSelectedCharacter()?.name ?? 'Default';
      final List<ChatMessage> messages =
          await chatService.getCharacterMessages(characterName);
      if (messages.isEmpty) return '';

      final recentMessages = messages.length <= maxConversations
          ? messages
          : messages.sublist(messages.length - maxConversations);

      final conversationContext = recentMessages.map((msg) {
        final role = msg.isUser ? 'User' : 'Assistant';
        return '$role: ${msg.text}';
      }).join('\n');

      return 'Previous conversation context:\n$conversationContext';
    } catch (e) {
      log('Error building conversation context: $e');
      return '';
    }
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

  String _buildConversationContext(String bookId) {
    final conversations = _conversationHistory[bookId];
    if (conversations == null || conversations.isEmpty) return '';

    final contextBuilder = StringBuffer("""
SYSTEM: You have access to the last few conversation exchanges between you and the user, numbered from [1] being the most recent to [${conversations.length}] being the oldest. Use this context to maintain consistency and build upon previous responses. Pay special attention to more recent exchanges (lower numbers) as they represent the current flow of conversation.

Past conversations (ordered from most recent to oldest):
""");

    int conversationNumber = 1;
    final List<ConversationEntry> orderedConversations =
        conversations.toList().reversed.toList();

    for (var entry in orderedConversations) {
      contextBuilder.writeln('[$conversationNumber]');
      contextBuilder.writeln('User: ${entry.userInput}');
      contextBuilder.writeln('Assistant: ${entry.aiResponse}\n');
      conversationNumber++;
    }

    return contextBuilder.toString();
  }

  void _addToConversationHistory(
      String bookId, String userInput, String aiResponse) {
    if (!_conversationHistory.containsKey(bookId)) {
      _conversationHistory[bookId] = Queue<ConversationEntry>();
    }

    final queue = _conversationHistory[bookId]!;
    if (queue.length >= maxConversations) {
      queue.removeFirst();
    }
    queue.add(ConversationEntry(userInput, aiResponse));
  }

  Future<String> askAboutText(
    String selectedText, {
    String? customPrompt,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    String task = 'analyze_text',
  }) async {
    try {
      if (!_isInitialized) {
        return 'Gemini service is not initialized. Please check your API key configuration.';
      }

      log('Current AI character: ${characterService.getSelectedCharacter()?.name ?? "none"}');

      // Get the appropriate prompt template based on task
      String finalPrompt = characterService.getPromptForTask(task);

      // Add conversation history to context
      final conversationContext = _buildConversationContext(bookTitle);

      // Handle custom prompt
      if (customPrompt != null && customPrompt.isNotEmpty) {
        if (finalPrompt.isNotEmpty) {
          finalPrompt = finalPrompt.replaceAll('{USER_PROMPT}', customPrompt);
          finalPrompt = """$finalPrompt

$conversationContext""";
        } else {
          finalPrompt = """
$customPrompt

Text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}

$conversationContext""";
        }
      }

      // If we still don't have a prompt, use a default one
      if (finalPrompt.isEmpty) {
        finalPrompt =
            """Please analyze this text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}

$conversationContext""";
      } else if (!finalPrompt.contains(conversationContext)) {
        finalPrompt = """$finalPrompt

$conversationContext""";
      }

      // Clean the selected text if provided
      String cleanedText = '';
      if (selectedText.isNotEmpty) {
        cleanedText = selectedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      log('Selected text length: ${cleanedText.length}');
      log('Final prompt before replacement: $finalPrompt');

      // Replace placeholders
      finalPrompt = finalPrompt
          .replaceAll('{TEXT}', cleanedText)
          .replaceAll('{BOOK_TITLE}', bookTitle)
          .replaceAll('{PAGE_NUMBER}', currentPage.toString())
          .replaceAll('{TOTAL_PAGES}', totalPages.toString())
          .replaceAll('{PROGRESS}',
              AiCharacterService.getProgressPercentage(currentPage, totalPages))
          .replaceAll('{CHARACTER_NAME}',
              characterService.getSelectedCharacter()?.name ?? 'AI Assistant')
          .replaceAll('{USER_PROMPT}', customPrompt ?? '');

      log('Final prompt after replacement: $finalPrompt');

      // Clean up any potential formatting issues
      finalPrompt = finalPrompt.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');

      final content = [Content.text(finalPrompt)];
      try {
        final response = await _model.generateContent(content);

        if (response.text != null) {
          // Store the conversation in memory
          _addToConversationHistory(
              bookTitle, customPrompt ?? selectedText, response.text!);

          // Only store in chat service if not an encouragement message (home screen)
          if (task != 'encouragement') {
            final characterName =
                characterService.getSelectedCharacter()?.name ?? 'AI Assistant';

            // Add user message
            await chatService.addMessage(ChatMessage(
              text: customPrompt ?? selectedText,
              isUser: true,
              timestamp: DateTime.now(),
              characterName: characterName,
              bookId: bookTitle,
            ));

            // Add AI response
            await chatService.addMessage(ChatMessage(
              text: response.text!,
              isUser: false,
              timestamp: DateTime.now(),
              characterName: characterName,
              bookId: bookTitle,
              avatarImagePath:
                  characterService.getSelectedCharacter()?.imagePath,
            ));
          }

          return response.text!;
        }

        // Check for specific error cases
        if (response.promptFeedback != null) {
          log('Prompt feedback: ${response.promptFeedback}');
          return "I apologize, but I cannot process this request due to content restrictions. Please try rephrasing your question.";
        }

        return _getDefaultMessage();
      } catch (e) {
        log('Error in Gemini API call: $e');
        if (e.toString().contains('PromptFeedback')) {
          return "I apologize, but I cannot process this request due to content restrictions. Please try rephrasing your question.";
        }
        return _getDefaultMessage();
      }
    } catch (e) {
      log('Error in askAboutText: $e');
      return _getDefaultMessage();
    }
  }

  String _getDefaultMessage() {
    return "I apologize, but I couldn't analyze the text. Please try selecting a different portion of text or try again.";
  }
}
