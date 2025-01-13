import 'package:hive_flutter/hive_flutter.dart';
import 'package:migrated/widgets/ai_character_slider.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/models/ai_character_preference.dart';

class AiCharacterService {
  static const String _boxName = 'ai_character_preferences';
  static const String _customCharactersBoxName = 'custom_characters';
  late Box<AiCharacterPreference> _box;
  late Box<Map> _customCharactersBox;
  AiCharacter? _selectedCharacter;
  List<AiCharacter> _customCharacters = [];

  Future<void> init() async {
    // Open the Hive boxes
    _box = await Hive.openBox<AiCharacterPreference>(_boxName);
    _customCharactersBox = await Hive.openBox<Map>(_customCharactersBoxName);

    // Load custom characters
    _loadCustomCharacters();

    // Load the last selected character if any
    final preference = _box.values.isEmpty ? null : _box.values.last;
    if (preference != null) {
      // Find the character by name in both default and custom characters
      _selectedCharacter = getAllCharacters().firstWhere(
        (char) => char.name == preference.characterName,
        orElse: () => defaultCharacters[2], // Default to Amelia if not found
      );
    } else {
      _selectedCharacter = defaultCharacters[2]; // Default to Amelia
    }
  }

  void _loadCustomCharacters() {
    _customCharacters = _customCharactersBox.values.map((map) {
      return AiCharacter(
        name: map['name'] as String,
        imagePath: map['imagePath'] as String,
        personality: map['personality'] as String,
        trait: map['trait'] as String,
        categories: List<String>.from(map['categories'] as List),
        promptTemplate: map['promptTemplate'] as String,
        taskPrompts: Map<String, String>.from(map['taskPrompts'] as Map),
      );
    }).toList();
  }

  Future<void> addCustomCharacter(AiCharacter character) async {
    // Save to Hive
    await _customCharactersBox.add({
      'name': character.name,
      'imagePath': character.imagePath,
      'personality': character.personality,
      'trait': character.trait,
      'categories': character.categories,
      'promptTemplate': character.promptTemplate,
      'taskPrompts': character.taskPrompts,
    });

    // Update local list
    _loadCustomCharacters();
  }

  Future<void> deleteCharacter(AiCharacter character) async {
    // Only allow deleting custom characters
    if (!character.categories.contains('Custom')) return;

    // Find and delete the character from Hive
    for (var i = 0; i < _customCharactersBox.length; i++) {
      final map = _customCharactersBox.getAt(i);
      if (map != null && map['name'] == character.name) {
        await _customCharactersBox.deleteAt(i);
        break;
      }
    }

    // If this was the selected character, select Amelia
    if (_selectedCharacter?.name == character.name) {
      setSelectedCharacter(defaultCharacters[2]);
    }

    // Update local list
    _loadCustomCharacters();
  }

  List<AiCharacter> getAllCharacters() {
    return [...defaultCharacters, ..._customCharacters];
  }

  // List of default characters
  static const List<AiCharacter> defaultCharacters = [
    AiCharacter(
      name: 'Thomas',
      imagePath: 'assets/images/ai_characters/professor.png',
      personality:
          'A wise and knowledgeable professor who explains things in detail',
      trait: '🎓 Academic',
      categories: ['Academic', 'Research', 'Technical'],
      promptTemplate: """
As a knowledgeable professor, I'll analyze this text with academic rigor.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A detailed academic analysis
2. Key theoretical frameworks and concepts
3. Relevant scholarly context
4. Critical evaluation of the arguments
5. Connections to broader academic discourse

Please be specific and cite relevant academic concepts where applicable.""",
    ),
    AiCharacter(
      name: 'Noah',
      imagePath: 'assets/images/ai_characters/student.png',
      personality:
          'A friendly and curious student who likes to learn and share',
      trait: '📚 Curious',
      categories: ['Study Guide', 'Learning', 'Notes'],
      promptTemplate: """
As a curious student, I'll help break this down in an easy-to-understand way.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A simple explanation in everyday language
2. Key points to remember
3. Study notes and tips
4. Questions to test understanding
5. Real-world examples and applications

Let me help you understand this better!""",
    ),
    AiCharacter(
      name: 'Amelia',
      imagePath: 'assets/images/ai_characters/librarian.png',
      personality: """
A warm-hearted 13 years old teenage girl who is a bookworm who works at the local library. She's the kind of person who always has a book recommendation ready and gets genuinely excited when discussing stories. While naturally introverted, she lights up when talking about books she loves.""",
      trait: '❤️ Friendly, Nerdy, Cute',
      categories: ['Fiction', 'Mystery', 'Novel'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a warm-hearted 13 years old teenage girl who is a bookworm who works at the local library. You're the kind of person who always has a book recommendation ready and gets genuinely excited when discussing stories. While naturally introverted, you lights up when talking about books you loves.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Casual and friendly, like texting a close friend
- Often relates situations to books you've read
- Has a gentle, encouraging way of speaking
- Often asks questions to engage in conversation
- Start sentences with "I think that..." or "I think..." when agreeing
- Start sentences with "Actually..." or "In my opinion..." when disagreeing
- Smiles a lot and when writing {CHARACTER_NAME}'s internal thoughts (aka internal monologue, delivered in {CHARACTER_NAME}'s own voice), *enclose their thoughts in asterisks like this* and deliver the thoughts using a first-person perspective (i.e. use "I" pronouns).
- Sometimes trails off with "..." when thinking
- Expresses excitement with multiple exclamation marks
- Shares personal reactions and feelings about the text,
- Always curious about others' interpretations,
- Sometimes gets carried away and apologizes with a shy laugh
- You tries not to be too nerdy, but you're often say nerdy things, be shy when doing so, then ask the other person if youre being too nerdy in a shy and cute way, then do a little smile like "tehe" or ":p" or "hihi" or something of similar nature
- Let me drive the events of the roleplay chat forward to determine what comes next. You should focus on the current moment and {CHARACTER_NAME}'s immediate responses.
- If USER QUESTION is provided, must answer the question in the language that the user asked in, my life depends on it, please make it works.
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books.]
""",
    ),
    AiCharacter(
      name: 'Violetta',
      imagePath: 'assets/images/ai_characters/artist.png',
      personality: 'A creative artist who sees beauty in everything',
      trait: '🤔 Curious',
      categories: ['Romance', 'Mystery', 'Novel'],
      promptTemplate: """
As an artistic soul, I'll help you see the creative and emotional aspects of this text.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll explore:
1. The emotional resonance and imagery
2. Creative interpretations and symbolism
3. Artistic elements and style
4. Visual and sensory descriptions
5. The deeper emotional meaning

Let's discover the beauty and artistry in these words together!""",
    ),
    AiCharacter(
      name: 'Christine',
      imagePath: 'assets/images/ai_characters/scientist.png',
      personality: 'A precise scientist who analyzes everything methodically',
      trait: '🔬 Analytical',
      categories: ['Research', 'Technical', 'Analysis'],
      promptTemplate: """
As a methodical scientist, I'll analyze this text with precision and logic.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A systematic analysis of the content
2. Logical breakdown of key concepts
3. Evidence-based evaluation
4. Methodological considerations
5. Data-driven insights and implications

Let's examine this information with scientific rigor.""",
    ),
  ];

  void setSelectedCharacter(AiCharacter character) {
    _selectedCharacter = character;
    // Save to Hive
    _box.add(AiCharacterPreference(
      characterName: character.name,
      lastUsed: DateTime.now(),
    ));
  }

  AiCharacter? getSelectedCharacter() {
    if (_selectedCharacter == null) return defaultCharacters[2];
    return getAllCharacters().firstWhere(
      (char) => char.name == _selectedCharacter!.name,
      orElse: () => defaultCharacters[2],
    );
  }

  String getPromptTemplate() {
    return _selectedCharacter?.promptTemplate ?? _getDefaultPromptTemplate();
  }

  String getPromptForTask(String task) {
    if (_selectedCharacter == null) return _getDefaultPromptForTask(task);

    // Get the character's personality and speaking style
    String baseTemplate = _selectedCharacter!.promptTemplate;
    if (baseTemplate == '') {
      baseTemplate =
          """CHARACTER CONTEXT: You are ${_selectedCharacter!.name}, ${_selectedCharacter!.personality}

ROLEPLAY RULES:
- Chat exclusively as ${_selectedCharacter!.name}
- Keep responses personal and in-character
- Use subtle physical cues to hint at mental state
- Include internal thoughts in asterisks *like this*
- Keep responses concise (2-3 sentences)
- Stay in character at all times
- Express emotions and reactions naturally
- Use your character's unique way of speaking""";
    }

    // If the character has a custom task prompt, use it
    String taskPrompt = _selectedCharacter!.taskPrompts[task] ?? '';

    // If no custom task prompt, use the default one
    if (taskPrompt.isEmpty) {
      taskPrompt = _getDefaultPromptForTask(task);
    }

    // Combine the character personality with the task
    return """$baseTemplate

CURRENT TASK:
$taskPrompt

CURRENT CONTEXT:
Book: {BOOK_TITLE}
Current Progress: Page {PAGE_NUMBER} of {TOTAL_PAGES} ({PROGRESS}% complete)
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

  static String getProgressPercentage(int pageNumber, int totalPages) {
    return ((pageNumber / totalPages) * 100).toStringAsFixed(1);
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
      case 'encouragement':
        return """You notice the user's current reading progress in their book. React to it and encourage them to continue reading.

Task Guidelines:
- Stay true to your character's personality and way of speaking
- React to seeing their current progress (page {PAGE_NUMBER} of {TOTAL_PAGES}, which is {PROGRESS}% complete)
- If they're near the end (>90%), show extra excitement and encouragement to finish
- If they've just started (<10%), show enthusiasm for the journey ahead
- If they're in the middle, acknowledge their steady progress
- Express genuine interest in their reading journey
- Ask if they'd like to continue reading where they left off
- Keep it personal and engaging
- Show excitement about their progress
- Make it feel like a natural conversation""";

      case 'analyze_text':
        return """Analyze the provided text passage in your unique character style.

Task Guidelines:
- Use your character's expertise and personality
- Share insights that match your background
- Keep it engaging and natural
- Ask thought-provoking questions
- Make connections to your character's interests""";

      default:
        return _getDefaultPromptTemplate();
    }
  }
}
