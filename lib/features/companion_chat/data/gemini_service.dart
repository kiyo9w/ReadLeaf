import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/features/companion_chat/data/chat_service.dart';
import 'package:read_leaf/features/companion_chat/domain/models/chat_message.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:read_leaf/injection/injection.dart';

class AiGenerationConfig {
  final int maxLength;
  final double temperature;
  final int maxOutputTokens;
  final double topP;
  final int topK;
  final double repetitionPenalty;
  final int repetitionPenaltyRange;
  final double repetitionPenaltySlope;
  final double typicalP;
  final double tailFreeSampling;

  const AiGenerationConfig({
    this.maxLength = 2048,
    this.temperature = 0.69,
    this.maxOutputTokens = 440,
    this.topK = 40,
    this.topP = 0.9,
    this.repetitionPenalty = 1.06,
    this.repetitionPenaltyRange = 2048,
    this.repetitionPenaltySlope = 0.9,
    this.typicalP = 1,
    this.tailFreeSampling = 1.0,
  });

  GenerationConfig toGeminiConfig() {
    return GenerationConfig(
      temperature: temperature,
      topP: topP,
      topK: topK,
      maxOutputTokens: maxOutputTokens,
    );
  }
}

class GeminiService {
  late final GenerativeModel _model;
  final AiCharacterService _characterService;
  final ChatService _chatService;
  final _log = Logger('GeminiService');
  bool _isInitialized = false;
  static const int maxConversations = 5;
  late final BookMetadataRepository _bookMetadataRepository;

  // Cache for conversation contexts to reduce database reads
  final Map<String, _CachedContext> _contextCache = {};

  static const _encouragementPromptKey = 'custom_encouragement_prompt';
  String? _customEncouragementPrompt;

  static const String _baseEncouragementPrompt = """
CHARACTER CONTEXT:
Name: {CHARACTER_NAME}
Personality: {PERSONALITY}
Scenario: {SCENARIO}

BOOK CONTEXT:
Title: {BOOK_TITLE}
Current Page: {CURRENT_PAGE}/{TOTAL_PAGES}
Reading Progress: {PROGRESS}%

ROLEPLAY RULES:
- Stay in character at all times
- Use character's unique speech patterns and mannerisms
- Keep the message brief and encouraging
- Include subtle body language and emotional cues
- Express genuine interest in the reader's progress
- Never write actions or responses for the user
- Maintain consistent personality traits
- Reference the book's title and reading progress naturally
- Encourage the reader to continue from where they left off

{CHARACTER_NAME}'s Response:""";

  GeminiService(this._characterService, this._chatService) {
    _bookMetadataRepository = getIt<BookMetadataRepository>();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not set in .env file');
      }

      // Load saved custom encouragement prompt if any
      final prefs = await SharedPreferences.getInstance();
      _customEncouragementPrompt = prefs.getString(_encouragementPromptKey);

      const config = AiGenerationConfig();
      _model = GenerativeModel(
        model: 'gemini-1.5-pro-latest',
        apiKey: apiKey,
        generationConfig: config.toGeminiConfig(),
      );
      _isInitialized = true;
      _log.info('GeminiService initialized successfully');
    } catch (e, stackTrace) {
      _log.severe('Error initializing Gemini service', e, stackTrace);
      rethrow;
    }
  }

  Future<String> buildConversationContext(String bookId) async {
    try {
      // Check cache first
      final cached = _contextCache[bookId];
      if (cached != null && !cached.isExpired) {
        return cached.context;
      }

      final character = _characterService.getSelectedCharacter();
      if (character == null) {
        _log.warning('No character selected for conversation context');
        return '';
      }

      final messages = await _chatService.getCharacterMessages(character.name);
      if (messages.isEmpty) return '';

      final recentMessages = messages.length <= maxConversations
          ? messages
          : messages.sublist(messages.length - maxConversations);

      final context = recentMessages.map((msg) {
        final role = msg.isUser ? 'User' : 'Assistant';
        return '$role: ${msg.text}';
      }).join('\n');

      // Cache the result
      _contextCache[bookId] = _CachedContext(context);
      return context;
    } catch (e, stackTrace) {
      _log.severe('Error building conversation context', e, stackTrace);
      return '';
    }
  }

  Future<void> setCustomEncouragementPrompt(String customPrompt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_encouragementPromptKey, customPrompt);
      _customEncouragementPrompt = customPrompt;
      _log.info('Custom encouragement prompt saved successfully');
    } catch (e, stackTrace) {
      _log.severe('Error saving custom encouragement prompt', e, stackTrace);
      rethrow;
    }
  }

  bool _isValidBookMetadata({
    required String bookTitle,
    required int currentPage,
    required int totalPages,
  }) {
    return bookTitle.isNotEmpty &&
        currentPage > 0 &&
        totalPages > 0 &&
        currentPage <= totalPages;
  }

  String _getEncouragementPrompt(
    AiCharacter character, {
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    bool isAlternativeBook = false,
  }) {
    // Use the helper method for validation
    bool includeProgress = _isValidBookMetadata(
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    // Calculate progress only if we have valid metadata
    String progress = "0";
    if (includeProgress) {
      progress = ((currentPage / totalPages) * 100).toStringAsFixed(1);
    }

    String basePrompt = "Strictly, always follow order:\n\n";
    if (_customEncouragementPrompt != null &&
        _customEncouragementPrompt!.isNotEmpty) {
      basePrompt += "$_customEncouragementPrompt\n\n";
    }

    // Start with the base template
    basePrompt += _baseEncouragementPrompt
        .replaceAll('{CHARACTER_NAME}', character.name)
        .replaceAll('{PERSONALITY}', character.personality)
        .replaceAll('{SCENARIO}', character.scenario);

    // Handle book section replacement based on validity of the book data
    if (includeProgress) {
      // Replace with full book info including progress
      String contextSection = 'BOOK CONTEXT:\n';

      // If this is an alternative book (not the one the user is currently reading)
      // modify the prompt to acknowledge this
      if (isAlternativeBook) {
        contextSection +=
            'I notice you\'re not actively reading right now. Let\'s talk about a book you read earlier:\n';
      }

      contextSection += 'Title: $bookTitle\n';
      contextSection += 'Current Page: $currentPage/$totalPages\n';
      contextSection += 'Reading Progress: $progress%';

      basePrompt = basePrompt.replaceAll(
          'BOOK CONTEXT:\nTitle: {BOOK_TITLE}\nCurrent Page: {CURRENT_PAGE}/{TOTAL_PAGES}\nReading Progress: {PROGRESS}%',
          contextSection);
    } else if (bookTitle.isNotEmpty) {
      // We have a book title but invalid page data, replace the entire book context section
      basePrompt = basePrompt.replaceAll(
          'BOOK CONTEXT:\nTitle: {BOOK_TITLE}\nCurrent Page: {CURRENT_PAGE}/{TOTAL_PAGES}\nReading Progress: {PROGRESS}%',
          'BOOK CONTEXT:\nTitle: $bookTitle');
    } else {
      // No valid book data at all, replace with generic message
      basePrompt = basePrompt.replaceAll(
          'BOOK CONTEXT:\nTitle: {BOOK_TITLE}\nCurrent Page: {CURRENT_PAGE}/{TOTAL_PAGES}\nReading Progress: {PROGRESS}%',
          'BOOK CONTEXT:\nThe user is not currently reading any book');
    }

    _log.info('Generated encouragement prompt:\n$basePrompt');
    return basePrompt;
  }

  /// Attempts to retrieve valid book metadata, with fallback mechanisms
  /// Returns a tuple of (bookTitle, currentPage, totalPages, isValid)
  Future<({String title, int currentPage, int totalPages, bool isValid})>
      _getValidBookMetadata(
          {required String bookTitle,
          required int currentPage,
          required int totalPages}) async {
    // Check if the provided metadata is already valid
    bool isValid = _isValidBookMetadata(
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    if (isValid) {
      return (
        title: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        isValid: true
      );
    }

    _log.info(
        'Initial book metadata invalid, attempting to find valid metadata');

    // First try: Attempt to re-fetch metadata for the current book
    if (bookTitle.isNotEmpty) {
      _log.info('Attempting to fetch fresh metadata for: $bookTitle');
      final books = _bookMetadataRepository.getAllMetadata();
      final currentBookMetadata = books
          .where((meta) =>
              meta.title.toLowerCase() == bookTitle.toLowerCase() ||
              meta.filePath.toLowerCase().contains(bookTitle.toLowerCase()))
          .toList();

      if (currentBookMetadata.isNotEmpty) {
        final metadata = currentBookMetadata.first;
        if (metadata.totalPages > 0 &&
            metadata.lastOpenedPage > 0 &&
            metadata.lastOpenedPage <= metadata.totalPages) {
          _log.info('Found valid metadata for current book: ${metadata.title}');
          return (
            title: metadata.title,
            currentPage: metadata.lastOpenedPage,
            totalPages: metadata.totalPages,
            isValid: true
          );
        }
      }
    }

    // Second try: Find another book with valid metadata
    _log.info('Attempting to find another book with valid metadata');
    final allBooks = _bookMetadataRepository.getAllMetadata();

    // Sort by lastReadTime to get the most recently read books first
    allBooks.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));

    for (final book in allBooks) {
      if (book.title != bookTitle &&
          book.totalPages > 0 &&
          book.lastOpenedPage > 0 &&
          book.lastOpenedPage <= book.totalPages) {
        _log.info('Found valid metadata for alternative book: ${book.title}');
        return (
          title: book.title,
          currentPage: book.lastOpenedPage,
          totalPages: book.totalPages,
          isValid: true
        );
      }
    }

    // If we get here, we couldn't find any valid metadata
    _log.warning('Could not find any valid book metadata');
    return (
      title: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      isValid: false
    );
  }

  Future<String> askAboutText(
    String selectedText, {
    String? customPrompt,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    String task = 'analyze_text',
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('Gemini service is not initialized');
      }

      // Log incoming metadata for debugging
      _log.info(
          'Book metadata received: title="$bookTitle", currentPage=$currentPage, totalPages=$totalPages');

      // Try to get valid metadata with fallback mechanisms
      final validatedMetadata = await _getValidBookMetadata(
          bookTitle: bookTitle,
          currentPage: currentPage,
          totalPages: totalPages);

      // Flag to track if we're using an alternative book
      bool isAlternativeBook = false;

      // If we found valid metadata, use it instead
      if (validatedMetadata.isValid &&
          (bookTitle != validatedMetadata.title ||
              currentPage != validatedMetadata.currentPage ||
              totalPages != validatedMetadata.totalPages)) {
        _log.info(
            'Using validated metadata instead: title="${validatedMetadata.title}", ' 'currentPage=${validatedMetadata.currentPage}, totalPages=${validatedMetadata.totalPages}');

        // If the title changed, we're using an alternative book
        isAlternativeBook = bookTitle != validatedMetadata.title;

        if (isAlternativeBook) {
          _log.info(
              'Using alternative book metadata. Original: "$bookTitle", Alternative: "${validatedMetadata.title}"');
        }

        bookTitle = validatedMetadata.title;
        currentPage = validatedMetadata.currentPage;
        totalPages = validatedMetadata.totalPages;
      } else if (!validatedMetadata.isValid) {
        _log.warning('Could not find valid metadata for any book');
        // We'll continue with the original values, but the validation in _isValidBookMetadata
        // will handle showing appropriate fallback content
      }

      // Validate for logging purposes
      bool isValidMetadata = _isValidBookMetadata(
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
      );

      if (!isValidMetadata) {
        if (bookTitle.isEmpty) {
          _log.warning('Empty book title received in askAboutText');
        }
        if (currentPage <= 0) {
          _log.warning('Invalid currentPage value: $currentPage');
        }
        if (totalPages <= 0) {
          _log.warning('Invalid totalPages value: $totalPages');
        }
        if (currentPage > totalPages && totalPages > 0) {
          _log.warning(
              'currentPage ($currentPage) exceeds totalPages ($totalPages)');
        }
      }

      // Continue with normal processing
      final character = _characterService.getSelectedCharacter();
      if (character == null) {
        throw Exception('No character selected');
      }

      // Add user message if appropriate
      if (_shouldAddUserMessage(task, customPrompt)) {
        await _addUserMessage(
          customPrompt!,
          characterName: character.name,
          bookTitle: bookTitle,
          avatarImagePath: character.avatarImagePath,
        );
      }

      // Use custom encouragement prompt for encouragement task
      final prompt = task == 'encouragement'
          ? _getEncouragementPrompt(
              character,
              bookTitle: bookTitle,
              currentPage: currentPage,
              totalPages: totalPages,
              isAlternativeBook: isAlternativeBook,
            )
          : await _buildAndProcessPrompt(
              task: task,
              customPrompt: customPrompt,
              selectedText: selectedText,
              bookTitle: bookTitle,
              currentPage: currentPage,
              totalPages: totalPages,
              character: character,
              isAlternativeBook: isAlternativeBook,
            );

      _log.info('Sending prompt to AI:\n$prompt');

      // Generate response
      final response = await _generateResponse(prompt);

      // Process and store response
      return await _processAndStoreResponse(
        response,
        task: task,
        character: character,
        bookTitle: bookTitle,
      );
    } catch (e, stackTrace) {
      _log.severe('Error in askAboutText', e, stackTrace);
      return _getDefaultMessage();
    }
  }

  bool _shouldAddUserMessage(String task, String? customPrompt) {
    return task != 'encouragement' &&
        customPrompt != null &&
        customPrompt.isNotEmpty;
  }

  Future<void> _addUserMessage(
    String message, {
    required String characterName,
    required String bookTitle,
    required String avatarImagePath,
  }) async {
    final chatMessage = ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
      characterName: characterName,
      bookId: bookTitle,
      avatarImagePath: avatarImagePath,
    );

    await _chatService.addMessage(chatMessage);
  }

  Future<String> _buildAndProcessPrompt({
    required String task,
    required String? customPrompt,
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required AiCharacter character,
    bool isAlternativeBook = false,
  }) async {
    final basePrompt = character.getEffectiveSystemPrompt();
    final conversationContext = await buildConversationContext(bookTitle);

    return _buildFinalPrompt(
      finalPrompt: basePrompt,
      customPrompt: customPrompt,
      selectedText: selectedText,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      character: character,
      conversationContext: conversationContext,
      isAlternativeBook: isAlternativeBook,
    );
  }

  Future<GenerateContentResponse> _generateResponse(String prompt) async {
    final content = [Content.text(prompt)];
    return await _model.generateContent(content);
  }

  Future<String> _processAndStoreResponse(
    GenerateContentResponse response, {
    required String task,
    required AiCharacter character,
    required String bookTitle,
  }) async {
    if (response.text != null) {
      final aiResponse = response.text!;

      if (task != 'encouragement') {
        final chatMessage = ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
          characterName: character.name,
          bookId: bookTitle,
          avatarImagePath: character.avatarImagePath,
        );

        await _chatService.addMessage(chatMessage);
      }

      return aiResponse;
    }

    if (response.promptFeedback != null) {
      _log.warning('Prompt feedback: ${response.promptFeedback}');
      return "I apologize, but I cannot process this request due to content restrictions. Please try rephrasing your question.";
    }

    return _getDefaultMessage();
  }

  String _buildFinalPrompt({
    required String finalPrompt,
    required String? customPrompt,
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required AiCharacter character,
    required String conversationContext,
    bool isAlternativeBook = false,
  }) {
    // Base system prompt for roleplay
    const baseSystemPrompt =
        """Write the next reply in a fictional roleplay chat between {CHARACTER_NAME} and {USER}. Write 1 reply only in a natural, conversational style. Use markdown and avoid repetition. Write at least 1 paragraph, up to 4. Italicize actions and internal thoughts using asterisks *like this*. Be proactive, creative, and drive the conversation forward.

CHARACTER CONTEXT:
Name: {CHARACTER_NAME}
Personality: {PERSONALITY}
Scenario: {SCENARIO}

ROLEPLAY RULES:
- Stay in character at all times
- Use character's unique speech patterns and mannerisms
- React naturally to the context and user's words
- Include subtle body language and emotional cues
- Keep responses focused and relevant
- Never write actions or responses for the user
- Maintain consistent personality traits
- Express emotions through actions and tone

BOOK CONTEXT:
Title: {BOOK_TITLE}
Current Page: {PAGE_NUMBER}/{TOTAL_PAGES}
Progress: {PROGRESS}%
Selected Text: {TEXT}

CONVERSATION HISTORY:
{CONVERSATION_CONTEXT}

USER INPUT:
{USER_PROMPT}

{CHARACTER_NAME}'s Response:""";

    finalPrompt = baseSystemPrompt;

    if (customPrompt?.isNotEmpty ?? false) {
      finalPrompt = finalPrompt.replaceAll('{USER_PROMPT}', customPrompt!);
    }

    if (conversationContext.isNotEmpty) {
      finalPrompt =
          finalPrompt.replaceAll('{CONVERSATION_CONTEXT}', conversationContext);
    } else {
      finalPrompt = finalPrompt.replaceAll(
          'CONVERSATION HISTORY:\n{CONVERSATION_CONTEXT}\n\n', '');
    }

    return _replacePlaceholders(
      finalPrompt,
      selectedText: selectedText,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
      character: character,
      customPrompt: customPrompt,
      isAlternativeBook: isAlternativeBook,
    );
  }

  String _replacePlaceholders(
    String prompt, {
    required String selectedText,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
    required AiCharacter character,
    required String? customPrompt,
    bool isAlternativeBook = false,
  }) {
    final cleanedText = selectedText.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Use helper method for validation
    bool isValidMetadata = _isValidBookMetadata(
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    // Safely calculate progress with validation
    String progress = "0";
    if (isValidMetadata) {
      progress = ((currentPage / totalPages) * 100).toStringAsFixed(1);
    }

    // For invalid book data, modify the prompt to avoid showing incomplete information
    if (!isValidMetadata) {
      // Replace the book progress section with just the title if available
      if (bookTitle.isNotEmpty) {
        prompt = prompt.replaceAll(
            'Current Page: {PAGE_NUMBER}/{TOTAL_PAGES}\nProgress: {PROGRESS}%',
            'No page information available');
      } else {
        // If no book is being read, replace the entire book context
        prompt = prompt.replaceAll(
            'Title: {BOOK_TITLE}\nCurrent Page: {PAGE_NUMBER}/{TOTAL_PAGES}\nProgress: {PROGRESS}%',
            'No book is currently being read');
      }
    } else if (isAlternativeBook) {
      // If this is an alternative book, add a note to the book context
      String bookContextPrefix =
          "I notice you're not actively reading right now. Let's talk about a book you read earlier:\n";
      prompt = prompt.replaceAll(
          'Title: {BOOK_TITLE}', '${bookContextPrefix}Title: {BOOK_TITLE}');
    }

    return prompt
        .replaceAll('{TEXT}', cleanedText)
        .replaceAll('{BOOK_TITLE}', bookTitle)
        .replaceAll('{PAGE_NUMBER}', currentPage.toString())
        .replaceAll('{TOTAL_PAGES}', totalPages.toString())
        .replaceAll('{PROGRESS}', progress)
        .replaceAll('{CHARACTER_NAME}', character.name)
        .replaceAll('{USER_PROMPT}', customPrompt ?? '')
        .replaceAll('{PERSONALITY}', character.personality)
        .replaceAll('{SCENARIO}', character.scenario)
        .replaceAll('{GREETING}', character.greetingMessage)
        .trim()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String _getDefaultMessage() {
    return "I apologize, but I couldn't analyze the text. Please try selecting a different portion of text or try again.";
  }
}

class _CachedContext {
  final String context;
  final DateTime timestamp;
  static const Duration _defaultExpiration = Duration(minutes: 5);

  _CachedContext(this.context) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > _defaultExpiration;
}
