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
  }) async {
    try {
      if (!_isInitialized) {
        return 'Gemini service is not initialized. Please check your API key configuration.';
      }

      if (selectedText.isEmpty) {
        return _getDefaultMessage();
      }

      log('Current AI character: ${characterService.getSelectedCharacter()?.name ?? "none"}');

      // Get the appropriate prompt template
      String finalPrompt;
      // First try to get the character's prompt template
      finalPrompt = characterService.getPromptTemplate();

      // Handle custom prompt
      if (customPrompt != null && customPrompt.isNotEmpty) {
        // If we have a character prompt, insert the custom prompt in the USER PROMPT section
        if (finalPrompt != null && finalPrompt.isNotEmpty) {
          finalPrompt = finalPrompt.replaceAll('{USER PROMPT}', customPrompt);
        } else {
          // If no character prompt, use the custom prompt directly
          finalPrompt = """
$customPrompt

Text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}""";
        }
      }

      // If we still don't have a prompt, use a default one
      if (finalPrompt == null || finalPrompt.isEmpty) {
        finalPrompt =
            """Please analyze this text from {BOOK_TITLE} (page {PAGE_NUMBER}):
{TEXT}""";
      }

      // Clean the selected text
      final cleanedText = selectedText
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '');

      log('Selected text length: ${cleanedText.length}');
      log('Final prompt before replacement: $finalPrompt');

      // Replace placeholders
      finalPrompt = finalPrompt
          .replaceAll('{TEXT}', cleanedText)
          .replaceAll('{BOOK_TITLE}', bookTitle)
          .replaceAll('{PAGE_NUMBER}', currentPage.toString())
          .replaceAll('{TOTAL_PAGES}', totalPages.toString());

      log('Final prompt after replacement: $finalPrompt');

      final content = [Content.text(finalPrompt)];
      final response = await _model.generateContent(content);

      if (response.text != null) {
        return response.text!;
      }

      return _getDefaultMessage();
    } catch (e) {
      log('Error in Gemini API call: $e');
      return _getDefaultMessage();
    }
  }

  String _getDefaultMessage() {
    return "I apologize, but I couldn't analyze the text. Please try selecting a different portion of text or try again.";
  }
}
