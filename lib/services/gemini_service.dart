import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/services/chat_service.dart';
import 'package:read_leaf/models/chat_message.dart';

class GeminiService {
  late final GenerativeModel _model;
  final AiCharacterService _characterService;
  final ChatService _chatService;
  bool _isInitialized = false;
  static const int maxConversations = 5;

  // Cache for conversation contexts to reduce database reads
  final Map<String, _CachedContext> _contextCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  GeminiService(this._characterService, this._chatService);

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not set in .env file');
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
      rethrow;
    }
  }

  Future<String> buildConversationContext(String bookId) async {
    try {
      // Check cache first
      final cached = _contextCache[bookId];
      if (cached != null && !cached.isExpired) {
        return cached.context;
      }

      final characterName =
          _characterService.getSelectedCharacter()?.name ?? 'Default';
      final messages = await _chatService.getCharacterMessages(characterName);
      if (messages.isEmpty) return '';

      final recentMessages = messages.length <= maxConversations
          ? messages
          : messages.sublist(messages.length - maxConversations);

      final context = recentMessages.map((msg) {
        final role = msg.isUser ? 'User' : 'Assistant';
        return '$role: ${msg.text}';
      }).join('\n');

      // Cache the result
      _contextCache[bookId] = _CachedContext(context);
      return context;
    } catch (e) {
      log('Error building conversation context: $e');
      return '';
    }
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
        throw Exception('Gemini service is not initialized');
      }

      final character = _characterService.getSelectedCharacter();
      final characterName = character?.name ?? 'AI Assistant';
      final characterImage = character?.imagePath;

      // Add user message if appropriate
      if (_shouldAddUserMessage(task, customPrompt)) {
        await _addUserMessage(
          customPrompt!,
          characterName: characterName,
          bookTitle: bookTitle,
        );
      }

      // Build and process prompt
      final prompt = await _buildAndProcessPrompt(
        task: task,
        customPrompt: customPrompt,
        selectedText: selectedText,
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        characterName: characterName,
      );

      // Generate response
      final response = await _generateResponse(prompt);

      // Process and store response
      return await _processAndStoreResponse(
        response,
        task: task,
        characterName: characterName,
        characterImage: characterImage,
        bookTitle: bookTitle,
      );
    } catch (e) {
      log('Error in askAboutText: $e');
      return _getDefaultMessage();
    }
  }

  bool _shouldAddUserMessage(String task, String? customPrompt) {
    return task != 'encouragement' && (customPrompt?.isNotEmpty ?? false);
  }

  Future<void> _addUserMessage(
    String message, {
    required String characterName,
    required String bookTitle,
  }) async {
    await _chatService.addMessage(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
      characterName: characterName,
      bookId: bookTitle,
    ));
  }

  Future<String> _buildAndProcessPrompt({
    required String task,
    required String? customPrompt,
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required String characterName,
  }) async {
    final basePrompt = _characterService.getPromptForTask(task);
    final conversationContext = await buildConversationContext(bookTitle);

    return _buildFinalPrompt(
      finalPrompt: basePrompt,
      customPrompt: customPrompt,
      selectedText: selectedText,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      characterName: characterName,
      conversationContext: conversationContext,
    );
  }

  Future<GenerateContentResponse> _generateResponse(String prompt) async {
    final content = [Content.text(prompt)];
    return await _model.generateContent(content);
  }

  Future<String> _processAndStoreResponse(
    GenerateContentResponse response, {
    required String task,
    required String characterName,
    required String? characterImage,
    required String bookTitle,
  }) async {
    if (response.text != null) {
      final aiResponse = response.text!;

      if (task != 'encouragement') {
        await _chatService.addMessage(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
          characterName: characterName,
          bookId: bookTitle,
          avatarImagePath: characterImage,
        ));
      }

      return aiResponse;
    }

    if (response.promptFeedback != null) {
      log('Prompt feedback: ${response.promptFeedback}');
      return "I apologize, but I cannot process this request due to content restrictions. Please try rephrasing your question.";
    }

    return _getDefaultMessage();
  }

  String _buildFinalPrompt({
    required String finalPrompt,
    required String? customPrompt,
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required String characterName,
    required String conversationContext,
  }) {
    if (customPrompt?.isNotEmpty ?? false) {
      finalPrompt = finalPrompt.isNotEmpty
          ? finalPrompt.replaceAll('{USER_PROMPT}', customPrompt!)
          : _buildDefaultPrompt(customPrompt!, bookTitle);
    }

    if (finalPrompt.isEmpty) {
      finalPrompt = _buildDefaultPrompt('Please analyze this text', bookTitle);
    }

    if (conversationContext.isNotEmpty) {
      finalPrompt =
          _appendConversationContext(finalPrompt, conversationContext);
    }

    return _replacePlaceholders(
      finalPrompt,
      selectedText: selectedText,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      characterName: characterName,
      customPrompt: customPrompt,
    );
  }

  String _buildDefaultPrompt(String prompt, String bookTitle) => """
$prompt

Text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}
""";

  String _appendConversationContext(String prompt, String context) => """$prompt

Previous conversation:
$context""";

  String _replacePlaceholders(
    String prompt, {
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required String characterName,
    required String? customPrompt,
  }) {
    final cleanedText = selectedText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return prompt
        .replaceAll('{TEXT}', cleanedText)
        .replaceAll('{BOOK_TITLE}', bookTitle)
        .replaceAll('{PAGE_NUMBER}', currentPage.toString())
        .replaceAll('{TOTAL_PAGES}', totalPages.toString())
        .replaceAll('{PROGRESS}',
            AiCharacterService.getProgressPercentage(currentPage, totalPages))
        .replaceAll('{CHARACTER_NAME}', characterName)
        .replaceAll('{USER_PROMPT}', customPrompt ?? '')
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String _getDefaultMessage() {
    return "I apologize, but I couldn't analyze the text. Please try selecting a different portion of text or try again.";
  }
}

class _CachedContext {
  final String context;
  final DateTime timestamp;
  static const Duration _defaultExpiration = Duration(minutes: 5);

  _CachedContext(this.context) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > _defaultExpiration;
}
