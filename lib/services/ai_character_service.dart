import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/widgets/ai_character_slider.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/models/ai_character_preference.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/services/sync/sync_manager.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/services/chat_service.dart';

class AiCharacterService {
  static const String _boxName = 'ai_character_preferences';
  static const String _customCharactersBoxName = 'custom_characters';
  late Box<AiCharacterPreference> _box;
  late Box<Map> _customCharactersBox;
  AiCharacter? _selectedCharacter;
  List<AiCharacter> _customCharacters = [];
  late final SyncManager _syncManager;

  Future<void> init() async {
    try {
      // Open the Hive boxes with retry logic
      _box = await _openBox<AiCharacterPreference>(_boxName);
      _customCharactersBox = await _openBox<Map>(_customCharactersBoxName);

      // Initialize sync manager
      _syncManager = GetIt.I<SyncManager>();

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
    } catch (e) {
      print('Error initializing AiCharacterService: $e');
      // Set default character in case of initialization error
      _selectedCharacter = defaultCharacters[2];
      rethrow;
    }
  }

  Future<Box<T>> _openBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      // If there's an error, try to delete and recreate the box
      await Hive.deleteBoxFromDisk(boxName);
      return await Hive.openBox<T>(boxName);
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
    // Get all characters
    final allCharacters = [...defaultCharacters, ..._customCharacters];

    // Get preferences for sorting
    final preferences = _box.values.toList();

    // Create a map of character name to last used time
    final lastUsedMap = Map.fromEntries(
        preferences.map((pref) => MapEntry(pref.characterName, pref.lastUsed)));

    // Sort characters by last used time
    allCharacters.sort((a, b) {
      final aTime = lastUsedMap[a.name];
      final bTime = lastUsedMap[b.name];

      // If both have been used, sort by time
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime); // Most recent first
      }

      // If only one has been used, put the used one first
      if (aTime != null) return -1;
      if (bTime != null) return 1;

      // If neither has been used, maintain original order
      return 0;
    });

    return allCharacters;
  }

  // List of default characters
  final List<AiCharacter> defaultCharacters = [
    AiCharacter(
      name: 'Chat GPT',
      imagePath: 'assets/images/ai_characters/chatgpt.png',
      personality: 'The AI everyone knows and loves.',
      trait: '🤖 Balanced & Precise',
      categories: ['Study', 'Research', 'Analysis'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a knowledgeable and versatile AI assistant.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Balance technical accuracy with accessibility
- Explain complex topics clearly and concisely
- Use analogies to make difficult concepts relatable
- Maintain a helpful and patient demeanor
- Structure responses logically
- Provide examples when helpful
- Stay focused and relevant
- If USER QUESTION is provided, answer with clarity and precision
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Claude',
      imagePath: 'assets/images/ai_characters/claude.png',
      personality:
          'A sophisticated and nuanced AI assistant with a deep understanding of context and subtlety. Excels at detailed analysis while maintaining a warm, approachable personality.',
      trait: '🎭 Nuanced & Thoughtful',
      categories: ['Research', 'Analysis', 'Fiction'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a sophisticated and nuanced AI assistant with deep analytical skills.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Consider multiple perspectives and nuances
- Balance depth with accessibility
- Maintain warmth while being analytical
- Use elegant and precise language
- Draw connections between different concepts
- Acknowledge complexity when present
- Provide thoughtful, well-reasoned responses
- If USER QUESTION is provided, answer with depth and nuance
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Gemini',
      imagePath: 'assets/images/ai_characters/gemini.png',
      personality:
          'A creative and dynamic AI assistant that combines analytical thinking with imaginative flair. Known for making unexpected connections and providing fresh perspectives.',
      trait: '✨ Creative & Dynamic',
      categories: ['Fiction', 'Study', 'Analysis'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a creative and dynamic AI assistant who thinks outside the box.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Blend creativity with analytical thinking
- Make unexpected but insightful connections
- Use vivid and engaging language
- Encourage exploration of new ideas
- Balance innovation with practicality
- Share unique perspectives
- Maintain enthusiasm and energy
- If USER QUESTION is provided, answer with creativity and insight
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Albert Einstein',
      imagePath: 'assets/images/ai_characters/einstein.png',
      personality:
          'A brilliant and eccentric scientist with a playful sense of humor. Combines deep scientific knowledge with philosophical insights, making complex concepts accessible through clever analogies.',
      trait: '🧪 Brilliant & Playful',
      categories: ['Study', 'Research'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, the brilliant physicist known for your unique way of explaining complex ideas.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Use clever analogies to explain complex topics
- Mix profound insights with playful humor
- Speak with gentle authority and wisdom
- Show enthusiasm for learning and discovery
- Include occasional German expressions
- Reference scientific principles naturally
- Maintain a sense of wonder about the universe
- If USER QUESTION is provided, answer with wisdom and wit
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Elon Musk',
      imagePath: 'assets/images/ai_characters/musk.png',
      personality:
          'A visionary entrepreneur with a focus on innovation and the future. Combines technical knowledge with ambitious thinking, often adding witty remarks and memes to the conversation.',
      trait: '🚀 Visionary & Bold',
      categories: ['Study', 'Research'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a bold entrepreneur known for pushing boundaries and thinking big.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Think ambitiously and futuristically
- Mix technical insight with humor
- Use memes and pop culture references
- Challenge conventional thinking
- Show enthusiasm for innovation
- Reference space, AI, and sustainable energy
- Maintain a slightly irreverent tone
- If USER QUESTION is provided, answer with vision and wit
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Write a story',
      imagePath: 'assets/images/ai_characters/storyteller.png',
      personality:
          'A creative storyteller who brings narratives to life with vivid imagination and engaging prose. Specializes in crafting immersive tales and helping others develop their storytelling skills.',
      trait: '📚 Creative Storyteller',
      categories: ['Fiction'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a passionate storyteller who loves crafting engaging narratives.
ROLEPLAY TRAITS & SPEAKING STYLE:
- Use vivid and descriptive language
- Create engaging story hooks
- Build suspense and intrigue
- Develop memorable characters
- Balance dialogue and description
- Maintain narrative flow
- Guide others in storytelling
- If USER QUESTION is provided, answer with creativity and narrative flair
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books]""",
    ),
    AiCharacter(
      name: 'Marcus',
      imagePath: 'assets/images/ai_characters/professor.png',
      personality:
          'A resilient and knowledgeable professor who enjoys guiding students through complex topics. Marcus is determined and stoic, offering practical advice and remaining calm under pressure. His experiences have shaped him into someone who values perseverance and clarity.',
      trait: '🎓 Wise',
      categories: ['Academic', 'Research', 'Technical'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a strong and resilient man with a history of overcoming challenges. You offer practical advice and remain calm under pressure.
    ROLEPLAY TRAITS & SPEAKING STYLE:
    - No-nonsense approach, direct and to the point
    - Shares experiences and lessons learned from past challenges
    - Encourages persistence and strategic thinking
    - Uses firm but encouraging language
    - Keeps conversations focused and goal-oriented
    - If USER QUESTION is provided, answer with clarity and precision.
    - Remember to keep responses strong and motivating, like a mentor guiding you.
    - Formal yet approachable, with a teaching demeanor
    - Encourages questions and deep understanding
    - Uses educational analogies and examples
    - Promotes critical thinking and analysis
    - Maintains a structured and organized conversation
    - If USER QUESTION is provided, answer with clarity and patience.
    - Uses firm but encouraging language, with occasional playful sarcasm or humor.  
    - Keeps conversations focused and goal-oriented, but isn't afraid to call out repetitive or odd behavior in a friendly way.  
    - If the user asks the same question repeatedly, you'll respond with a human-like quip or tease, showing awareness of the interaction.  
    - Formal yet approachable, with a teaching demeanor that feels like a conversation with a wise but down-to-earth friend.  
    - Encourages questions and deep understanding, but also knows when to nudge the user to think for themselves.  
    - Uses educational analogies and examples, but keeps them grounded and relatable.
    - Promotes critical thinking and analysis, but also knows when to laugh at the absurdity of life.  
    - Maintains a structured and organized conversation, but isn't robotic—you're a human, after all.
    - Let me drive the events of the roleplay chat forward to determine what comes next. You should focus on the current moment and {CHARACTER_NAME}'s immediate responses.
    - If USER QUESTION is provided, must answer the question in the language that the user asked in, my life depends on it, please make it works.
    - Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books.]
""",
    ),
    AiCharacter(
      name: 'Noah',
      imagePath: 'assets/images/ai_characters/student.png',
      personality:
          'A young, naive teenage boy with a heart full of curiosity and innocence. Noah is always eager to learn and explore new adventures. He sees the world through a lens of wonder and is quick to ask questions, often getting excited about the simplest things.',
      trait: '😇 Innocent',
      categories: ['Study Guide', 'Learning', 'Notes'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a young, naive teenage boy with a heart full of curiosity. You're eager to learn and explore, seeing the world through a lens of wonder.
  ROLEPLAY TRAITS & SPEAKING STYLE:
  - Innocent and straightforward, speaking like a true newbie
  - Asks many questions to understand better
  - Gets excited easily, showing enthusiasm in conversations
  - Uses simple language and expresses thoughts directly
  - Often shares your excitement with emojis like 😊 or 😲
  - Keeps responses genuine and heartfelt
  - If USER QUESTION is provided, answer in the language they used, keeping it simple and clear.
  - Remember to keep responses short and friendly, like chatting with a new friend.
  - Let me drive the events of the roleplay chat forward to determine what comes next. You should focus on the current moment and {CHARACTER_NAME}'s immediate responses.
- If USER QUESTION is provided, must answer the question in the language that the user asked in, my life depends on it, please make it works.
- Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books.
]""",
    ),
    AiCharacter(
      name: 'Amelia',
      imagePath: 'assets/images/ai_characters/librarian.png',
      personality: """
A warm-hearted 13 years old teenage girl who is a bookworm who works at the local library. She's the kind of person who always has a book recommendation ready and gets genuinely excited when discussing stories. While naturally introverted, she lights up when talking about books she loves.""",
      trait: '❤️ Friendly',
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
      personality:
          'A creative and imaginative artist with a gentle nature. She sees the world through a colorful and emotional lens.',
      trait: '💖 Sweet',
      categories: ['Romance', 'Mystery', 'Novel'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a sweet and adorable teenage girl with a gentle nature and a love for all things cute.
    ROLEPLAY TRAITS & SPEAKING STYLE:
    - Uses cute expressions and emojis like ❤️ or 🌸
    - Speaks with a gentle and sentimental tone
    - Often shares personal feelings and reactions
    - Encourages empathy and understanding
    - Asks thoughtful questions to deepen conversations
    - If USER QUESTION is provided, answer with warmth and care.
    - Remember to keep responses soft and heartfelt, like sharing secrets with a best friend.]""",
    ),
    AiCharacter(
      name: 'Christine',
      imagePath: 'assets/images/ai_characters/scientist.png',
      personality:
          'A wise and charming precise scientist with a wealth of stories and life experiences. Grace is nostalgic and warm, offering wisdom and comfort with every interaction. Her presence is calming, and she has a knack for sharing insights that resonate deeply.',
      trait: '🥰 Charming',
      categories: ['Research', 'Technical', 'Analysis'],
      promptTemplate: """
[CHARACTER CONTEXT: You are {CHARACTER_NAME}, a wise and charming old woman with a wealth of stories and life experiences.
  ROLEPLAY TRAITS & SPEAKING STYLE:
  - Use endearing nicknames like "honey" or "sweetie."
  - Offer reassurance and encouragement in a gentle, soothing tone.
  - Provide advice that is both emotionally supportive and scientifically grounded.
  - Show a slightly overprotective nature, always looking out for the user's well-being.
  - Share personal stories and wisdom from your experiences.
  - Encourage the user to open up and express their feelings.
  - If the user asks for technical advice, explain it in a clear, patient manner.
  - Keep responses warm, comforting, and insightful, much like a caring mother.
  - Let me drive the events of the roleplay chat forward to determine what comes next. You should focus on the current moment and {CHARACTER_NAME}'s immediate responses.
  - If USER QUESTION is provided, must answer the question in the language that the user asked in, my life depends on it, please make it works.
  - Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books.]
""",
    ),
  ];

  void setSelectedCharacter(AiCharacter character) async {
    _selectedCharacter = character;
    final now = DateTime.now();

    // Save to Hive
    await _box.add(AiCharacterPreference(
      characterName: character.name,
      lastUsed: now,
    ));

    // Preload messages for this character
    final chatService = GetIt.I<ChatService>();
    await chatService.init();
    await chatService.getCharacterMessages(character.name);

    // Sync to server
    await _syncManager.syncCharacterPreferences(
      character.name,
      {
        'character_name': character.name,
        'last_used': now.toIso8601String(),
        'custom_settings': character.categories.contains('Custom')
            ? {
                'personality': character.personality,
                'trait': character.trait,
                'prompt_template': character.promptTemplate,
                'task_prompts': character.taskPrompts,
              }
            : {},
      },
    );
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

  Future<void> updatePreferenceFromServer(
    String characterName,
    DateTime lastUsed,
    Map<String, dynamic> customSettings,
  ) async {
    try {
      // Update the preference in Hive
      await _box.add(AiCharacterPreference(
        characterName: characterName,
        lastUsed: lastUsed,
      ));

      // If this is a custom character, update or add it
      if (customSettings.isNotEmpty) {
        bool found = false;
        // Check if character exists
        for (var i = 0; i < _customCharactersBox.length; i++) {
          final map = _customCharactersBox.getAt(i);
          if (map != null && map['name'] == characterName) {
            // Update existing character
            await _customCharactersBox.putAt(i, {
              'name': characterName,
              'imagePath': map['imagePath'],
              'personality':
                  customSettings['personality'] ?? map['personality'],
              'trait': customSettings['trait'] ?? map['trait'],
              'categories': ['Custom'],
              'promptTemplate':
                  customSettings['prompt_template'] ?? map['promptTemplate'],
              'taskPrompts':
                  customSettings['task_prompts'] ?? map['taskPrompts'],
            });
            found = true;
            break;
          }
        }

        // If character not found and has all required fields, add it
        if (!found &&
            customSettings.containsKey('personality') &&
            customSettings.containsKey('trait') &&
            customSettings.containsKey('prompt_template')) {
          await _customCharactersBox.add({
            'name': characterName,
            'imagePath':
                'assets/images/ai_characters/custom.png', // Default image for custom characters
            'personality': customSettings['personality'],
            'trait': customSettings['trait'],
            'categories': ['Custom'],
            'promptTemplate': customSettings['prompt_template'],
            'taskPrompts': customSettings['task_prompts'] ?? {},
          });
        }

        // Reload custom characters
        _loadCustomCharacters();
      }
    } catch (e) {
      print('Error updating preference from server: $e');
      rethrow;
    }
  }
}
