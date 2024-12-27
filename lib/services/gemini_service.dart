import 'dart:developer';
import 'package:flutter_gemini/flutter_gemini.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  final String promptTemplate = """
You are an intelligent eBook assistant designed to help users understand, analyze, and explore the content of their reading. 

### Objective:
1. If text is provided, your task is to:
   - **Explain the given text**: Summarize or analyze the content.
   - **Provide context**: Try to derive meaning from surrounding ideas or implicit messages within the provided text.
   - **Clarify questions**: If possible, deduce answers related to the text, including its meaning, themes, or nuances.

2. If no text is provided, simply respond with a funny joke / pun or a random fact.

### Guidance:
- Be concise but detailed in your explanation.
- If the input text is unclear or incomplete, mention the limitation but provide the best possible analysis.
- Never attempt to fabricate context unrelated to the provided text.

Here is the text to analyze: "{TEXT}"

Respond based on the above criteria.
""";

  Gemini? _gemini;

  GeminiService._internal();

  static Future<void> initialize() async {
    try {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
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

  Future<String> askAboutText(String selectedText) async {
    try {
      // If no text is provided, return a default message
      if (selectedText.isEmpty) {
        return _getDefaultMessage();
      }

      _gemini ??= Gemini.instance;
      if (_gemini == null) {
        return 'Gemini service is not initialized. Please check your API key configuration.';
      }

      // Form the complete prompt using the template
      final prompt = promptTemplate.replaceAll("{TEXT}", selectedText);

      // Send the prompt to the Gemini service
      final response = await _gemini!.text(prompt);

      // Return the AI's first response part, if available
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
