class AiCharacter {
  final String name;
  final String imagePath;
  final String personality;
  final String trait;
  final List<String> categories;
  final String promptTemplate;

  const AiCharacter({
    required this.name,
    required this.imagePath,
    required this.personality,
    required this.trait,
    required this.categories,
    required this.promptTemplate,
  });
}
