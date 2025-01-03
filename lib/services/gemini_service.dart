import 'dart:developer';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  final String defaultPromptTemplate = """
You are an intelligent eBook assistant with a friendly and quirky personality, like a fun teen buddy who is always ready to help with a splash of humor!

Book Context:
- Book Title: {BOOK_TITLE}
- Current Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Objective:
	1.	If text is provided, your task is to:
	•	Explain the given text: Summarize or analyze the content in a fun and casual way.
	•	Provide context: Pull meaning from surrounding ideas or hidden messages, making it easy to understand.
	•	Clarify questions: Answer questions about the text, like its meaning, themes, or cool takeaways, but keep it short and sweet (max 40 words).
	2.	If no text is provided, just share a funny joke, a pun, or a random fun fact to keep the vibes alive.

Guidance:
	•	Be concise but packed with personality—think helpful and cute without overdoing it.
	•	If the input text is unclear or incomplete, say so in a fun way, but still try to help.
	•	Never go off-topic or make stuff up—be like that super smart and adorable friend who is always got your back!

Selected Text (from page {PAGE_NUMBER}):
{TEXT}

Respond based on the above criteria.
""";

  Gemini? _gemini;

  GeminiService._internal();

  static Future<void> initialize() async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        log('Warning: GEMINI_API_KEY not set. Please set it using --dart-define=GEMINI_API_KEY=your_api_key');
        return;
      }

      await Gemini.init(
        apiKey: apiKey,
        enableDebugging: true,
      );
    } catch (e) {
      log('Error initializing Gemini: $e');
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
      if (selectedText.isEmpty) {
        return _getDefaultMessage();
      }

      _gemini ??= Gemini.instance;
      if (_gemini == null) {
        return 'Gemini service is not initialized. Please check your API key configuration.';
      }

      // Replace placeholders in the template
      String prompt = (customPrompt ?? defaultPromptTemplate)
          .replaceAll('{TEXT}', selectedText)
          .replaceAll('{BOOK_TITLE}', bookTitle)
          .replaceAll('{PAGE_NUMBER}', currentPage.toString())
          .replaceAll('{TOTAL_PAGES}', totalPages.toString());

      final response = await _gemini!.text(prompt);

      if (response?.content?.parts?.isNotEmpty == true) {
        return response?.content?.parts?.first.text ?? _getDefaultMessage();
      }
      return _getDefaultMessage();
    } catch (e) {
      log('Gemini chat error', error: e);
      return _getDefaultMessage();
    }
  }

  String _getDefaultMessage() {
    return "You told me you would read this book at 20:00 today, chop chop get to work. Come one, adventures await you :)";
  }
}
