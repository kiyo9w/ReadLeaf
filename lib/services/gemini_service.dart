import 'dart:developer';
import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  late final GenerativeModel _model;
  AiCharacterService? _characterService;
  bool _isInitialized = false;

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

      // Handle custom prompt
      if (customPrompt != null && customPrompt.isNotEmpty) {
        // If we have a character prompt, insert the custom prompt in the USER PROMPT section
        if (finalPrompt.isNotEmpty) {
          finalPrompt = finalPrompt.replaceAll('{USER_PROMPT}', customPrompt);
        } else {
          // If no character prompt, use the custom prompt directly
          finalPrompt = """
$customPrompt

Text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}""";
        }
      }

      // If we still don't have a prompt, use a default one
      if (finalPrompt.isEmpty) {
        finalPrompt =
            """Please analyze this text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}""";
      }

      // Clean the selected text if provided
      String cleanedText = '';
      if (selectedText.isNotEmpty) {
        cleanedText = selectedText
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      }

      log('Selected text length: ${cleanedText.length}');
      log('Final prompt before replacement: $finalPrompt');

      // Replace placeholders
      finalPrompt = finalPrompt
          .replaceAll('{TEXT}', cleanedText)
          .replaceAll('{BOOK_TITLE}', bookTitle)
          .replaceAll('{PAGE_NUMBER}', currentPage.toString())
          .replaceAll('{TOTAL_PAGES}', totalPages.toString())
          .replaceAll('{PROGRESS}', characterService.getProgressPercentage(currentPage, totalPages))
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
