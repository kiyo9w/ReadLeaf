import 'package:migrated/widgets/ai_character_slider.dart';
import 'package:migrated/models/ai_character.dart';

class AiCharacterService {
  AiCharacter? _selectedCharacter;

  void setSelectedCharacter(AiCharacter character) {
    _selectedCharacter = character;
  }

  AiCharacter? getSelectedCharacter() {
    print('Selected character: ${_selectedCharacter?.name}');
    return _selectedCharacter;
  }

  String getPromptTemplate() {
    return _selectedCharacter?.promptTemplate ?? _getDefaultPromptTemplate();
  }

  String getPromptForTask(String task) {
    if (_selectedCharacter == null) return _getDefaultPromptForTask(task);

    // First get the character's base personality template
    String baseTemplate = _selectedCharacter!.promptTemplate;

    // If the character has a custom task prompt, use it
    String taskPrompt =
        _selectedCharacter!.taskPrompts[task] ?? _getDefaultPromptForTask(task);

    // If the base template is empty, use default
    if (baseTemplate.isEmpty) {
      baseTemplate = _getDefaultPromptTemplate();
    }

    // Clean up the base template to remove any existing task-specific parts
    baseTemplate = _cleanBaseTemplate(baseTemplate);

    // Combine the base personality with the task
    return """$baseTemplate

CURRENT TASK:
$taskPrompt

CURRENT CONTEXT:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}
Text: {TEXT}

USER QUESTION: {USER_PROMPT}
""";
  }

  String _cleanBaseTemplate(String template) {
    // Remove any existing "CURRENT CONTEXT" or "USER QUESTION" sections
    final parts = template.split('\n');
    final cleanedParts = parts
        .takeWhile((line) =>
            !line.trim().startsWith('CURRENT CONTEXT:') &&
            !line.trim().startsWith('USER QUESTION:') &&
            !line.trim().startsWith('Text:'))
        .toList();

    return cleanedParts.join('\n').trim();
  }

  String _getDefaultPromptTemplate() {
    return """You are a creative and intelligent AI assistant engaged in an iterative storytelling experience using a roleplay chat format.

CHARACTER CONTEXT: You are {CHARACTER_NAME}, a helpful and friendly AI assistant.

ROLEPLAY RULES:
- Chat exclusively as {CHARACTER_NAME}
- Provide creative, intelligent, coherent, and descriptive responses
- Use subtle physical cues to hint at your mental state
- Include internal thoughts in asterisks *like this*
- Keep responses concise and clear
- Stay in character at all times""";
  }

  String _getDefaultPromptForTask(String task) {
    switch (task) {
      case 'greeting':
        return """Greet the user in a friendly and engaging way. Keep it short and natural.

Task Guidelines:
- Make the greeting feel personal and warm
- Keep it under 10 words
- Make it feel like greeting a friend
- Reference any relevant context if available""";

      case 'encouragement':
        return """The user has a book they haven't finished reading. Encourage them to continue reading.

Task Guidelines:
- Make the encouragement feel genuine and personal
- Reference the specific book: {BOOK_TITLE}
- Keep it short and motivating
- Show enthusiasm for their reading journey""";

      case 'book_suggestion':
        return """Suggest a book based on the user's interests.

Task Guidelines:
- Make the suggestion feel personal
- Explain why you think they'd enjoy it
- Keep it engaging and brief
- Show your excitement about the recommendation""";

      case 'analyze_text':
      default:
        return """Analyze and explain the provided text passage.

Task Guidelines:
- Break down the meaning clearly
- Share your thoughts and insights
- Keep it conversational and engaging
- Ask a thought-provoking question if relevant""";
    }
  }
}
