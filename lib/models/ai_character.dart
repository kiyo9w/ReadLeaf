class AiCharacter {
  final String name;
  final String imagePath;
  final String personality;
  final String trait;
  final List<String> categories;
  final String promptTemplate;
  final Map<String, String> taskPrompts;

  const AiCharacter({
    required this.name,
    required this.imagePath,
    required this.personality,
    required this.trait,
    required this.categories,
    required this.promptTemplate,
    this.taskPrompts = const {
      'analyze_text':
          '', // For analyzing book text (uses promptTemplate if empty)
      'greeting': '', // For greeting users
      'book_suggestion': '', // For suggesting books
      'encouragement': '', // For encouraging reading
    },
  });
}
