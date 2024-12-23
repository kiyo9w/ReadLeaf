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

  late final Gemini gemini;

  GeminiService._internal() {
    gemini = Gemini.instance;
  }

  static Future<void> initialize() async {
    Gemini.init(
        apiKey: '',
        enableDebugging: true);
  }

  
  Future<String?> askAboutText(String selectedText) async {
    try {
      // Determine the text input for the prompt
      final inputText = selectedText.isEmpty ? "No text was given." : selectedText;

      // Form the complete prompt using the template
      final prompt = promptTemplate.replaceAll("{TEXT}", inputText);

      // Send the prompt to the Gemini service
      final response = await gemini.text(prompt);

      // Return the AI's first response part, if available
      if (response?.content?.parts?.isNotEmpty == true) {
        return response?.content?.parts?.first.text;
      }
      return null;
    } catch (e) {
      log('Gemini chat error', error: e);
      return null;
    }
  }
}
