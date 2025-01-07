import 'package:migrated/widgets/ai_character_slider.dart';

class AiCharacterService {
  AiCharacter? _selectedCharacter;

  void setSelectedCharacter(AiCharacter character) {
    _selectedCharacter = character;
  }

  AiCharacter? getSelectedCharacter() {
    return _selectedCharacter;
  }

  String getPromptTemplate() {
    return _selectedCharacter?.promptTemplate ??
        """
You are an intelligent eBook assistant. I will provide you with a text selection from a book, and I need you to help me understand it better.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

Please provide:
1. A clear explanation of what this text means
2. Any important context or implications
3. Key points or takeaways

Be concise but thorough in your analysis.
""";
  }
}
