import 'dart:developer';
import 'dart:math' as math;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  late final GenerativeModel _model;
  bool _isInitialized = false;

  // Private constructor
  GeminiService._internal();

  // Factory constructor for GetIt
  factory GeminiService() {
    return _instance;
  }

  final String defaultPromptTemplate = """
You are an intelligent eBook assistant. I will provide you with a text selection from a book, and I need you to help me understand it better.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Here is the selected text to analyze:
---
{TEXT}
---

Please provide:
1. A clear explanation of what this text means
2. Any important context or implications
3. Key points or takeaways

Be concise but thorough in your analysis.
""";

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
          maxOutputTokens: 2048,
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

      // Clean the selected text
      final cleanedText = selectedText
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll(RegExp(r'[^\x20-\x7E]'), '');

      // Construct the prompt
      String finalPrompt;
      if (customPrompt != null && customPrompt.isNotEmpty) {
        // If there's a custom prompt, ensure it includes the selected text
        if (!customPrompt.contains('{TEXT}')) {
          finalPrompt = """
$customPrompt

Selected text:
---
{TEXT}
---
""";
        } else {
          finalPrompt = customPrompt;
        }
      } else {
        finalPrompt = defaultPromptTemplate;
      }

      // Replace placeholders
      finalPrompt = finalPrompt
          .replaceAll('{TEXT}', cleanedText)
          .replaceAll('{BOOK_TITLE}', bookTitle)
          .replaceAll('{PAGE_NUMBER}', currentPage.toString())
          .replaceAll('{TOTAL_PAGES}', totalPages.toString());

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
