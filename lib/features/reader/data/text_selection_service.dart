import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/floating_selection_menu.dart';

/// Service to handle text selection operations - dictionary lookup, translation,
/// Wikipedia information and more.
class TextSelectionService {
  final GeminiService _geminiService = GetIt.I<GeminiService>();
  final _logger = Logger('TextSelectionService');
  final Dio _dio = Dio();

  // API endpoints
  static const String _dictionaryApiUrl =
      'https://api.dictionaryapi.dev/api/v2/entries';
  static const String _wikipediaApiBaseUrl = 'https://api.rest.v1/page/summary';

  TextSelectionService() {
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 5);
    _dio.options.headers = {
      'User-Agent': 'ReadLeaf/1.0 (hello@readleaf.app)',
      'Accept': 'application/json',
    };

    _dio.options.validateStatus = (status) {
      return true;
    };
  }

  /// Look up a word or phrase in a dictionary
  /// [word] - The word to look up
  /// [language] - Language code (en, es, fr, etc.)
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> getDictionaryDefinition(String word,
      {String language = 'en',
      String bookTitle = 'Dictionary',
      int currentPage = 1,
      int totalPages = 1}) async {
    try {
      _logger.info('Getting dictionary definition for "$word" in $language');

      // Clean up the word - remove extra spaces, punctuation, etc.
      final cleanWord = _sanitizeSearchTerm(word);

      if (cleanWord.isEmpty) {
        return _createErrorResponse('Word cannot be empty', 'dictionary');
      }

      // English can use the free dictionary API
      if (language == 'en') {
        return await _fetchDictionaryFromApi(cleanWord, language);
      }

      // Non-English languages use Gemini
      return await _getGeminiDefinition(
          word, language, bookTitle, currentPage, totalPages);
    } catch (e, stackTrace) {
      _logger.severe('Error getting dictionary definition', e, stackTrace);
      return _createErrorResponse(e.toString(), 'dictionary');
    }
  }

  /// Get Wikipedia information about a term
  /// [term] - The term to look up
  /// [language] - Language code for Wikipedia (en, es, fr, etc.)
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> getWikipediaInformation(String term,
      {String language = 'en',
      String bookTitle = 'Wikipedia',
      int currentPage = 1,
      int totalPages = 1}) async {
    try {
      _logger.info('Getting Wikipedia info for "$term" in $language');

      // Clean up the term
      final cleanTerm = _sanitizeSearchTerm(term);
      if (cleanTerm.isEmpty) {
        return _createErrorResponse('Term cannot be empty', 'wikipedia');
      }

      // Try the Wikipedia API first
      try {
        final encodedTerm = Uri.encodeComponent(cleanTerm);
        final url =
            'https://$language.wikipedia.org/api/rest_v1/page/summary/$encodedTerm';

        final response = await _dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': 'ReadLeaf/1.0 (hello@readleaf.app)',
              'Accept': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          return {
            'success': true,
            'source': 'wikipedia-api',
            'data': data,
            'term': cleanTerm,
            'language': language,
          };
        } else {
          _logger.info(
              'Wikipedia API returned status code ${response.statusCode}, falling back to Gemini');
        }
      } catch (apiError) {
        _logger
            .warning('Wikipedia API error, falling back to Gemini: $apiError');
      }

      // Fall back to Gemini for providing general information
      return await _getGeminiWikipediaInfo(
          term, language, bookTitle, currentPage, totalPages);
    } catch (e, stackTrace) {
      _logger.severe('Error getting Wikipedia information', e, stackTrace);
      return _createErrorResponse(e.toString(), 'wikipedia');
    }
  }

  /// Translate text from one language to another
  /// [text] - The text to translate
  /// [targetLanguage] - The target language (Spanish, French, etc.)
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> translateText(String text, String targetLanguage,
      {String bookTitle = 'Translation',
      int currentPage = 1,
      int totalPages = 1}) async {
    return await _processTextWithAi(
      text: text,
      operation: 'translation',
      targetLanguage: targetLanguage,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// Generate an image description from text
  /// [text] - The text to generate an image description for
  /// [style] - The style of the image description
  /// [customPrompt] - Custom prompt for generating the image description
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> generateImagePrompt(String text, String style,
      {String? customPrompt,
      String bookTitle = 'Image Generation',
      int currentPage = 1,
      int totalPages = 1}) async {
    return await _processTextWithAi(
      text: text,
      operation: 'generate_image',
      style: style,
      customPrompt: customPrompt,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// Process a query with AI assistant through Gemini
  /// [text] - The text to process
  /// [customPrompt] - Custom prompt for the AI
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> askAi(String text, String customPrompt,
      {String bookTitle = 'Ask AI',
      int currentPage = 1,
      int totalPages = 1}) async {
    return await _processTextWithAi(
      text: text,
      operation: 'ask_ai',
      customPrompt: customPrompt,
      bookTitle: bookTitle,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// Unified method to handle all text operations with AI
  /// [text] - The text to process
  /// [operation] - The type of operation to perform
  /// [customPrompt] - Custom prompt for the AI
  /// [targetLanguage] - Target language for translation
  /// [style] - Style for image generation
  /// [bookTitle] - Title of the book being read
  /// [currentPage] - Current page in the book
  /// [totalPages] - Total pages in the book
  Future<Map<String, dynamic>> _processTextWithAi({
    required String text,
    required String operation,
    String? customPrompt,
    String? targetLanguage,
    String? style,
    required String bookTitle,
    required int currentPage,
    required int totalPages,
  }) async {
    try {
      _logger.info('Processing text with operation: $operation');

      if (text.trim().isEmpty) {
        return _createErrorResponse('Text cannot be empty', operation);
      }

      // Generate appropriate prompt based on operation
      String prompt;
      switch (operation) {
        case 'translation':
          prompt = '''
Translate the following text to ${targetLanguage ?? 'Spanish'}. 
Return only the translation without any additional text or explanations.

Text to translate:
"""$text"""
''';
          break;

        case 'generate_image':
          prompt = customPrompt?.isNotEmpty == true
              ? '''$customPrompt

Text to imagine:
"""$text"""
'''
              : '''
Create a detailed image description based on this text excerpt.
Style: ${style ?? 'Realistic'}
Make the description vivid, detailed, and suitable for image generation.

Text to imagine:
"""$text"""
''';
          break;

        case 'ask_ai':
          prompt = customPrompt?.isNotEmpty == true
              ? '''$customPrompt

Text excerpt:
"""$text"""
'''
              : '''Analyze this text and provide insights about its meaning and significance.

Text excerpt:
"""$text"""
''';
          break;

        default:
          prompt = customPrompt ??
              '''Analyze this text and provide insights. 
          
Text:
"""$text"""
''';
      }

      // Call Gemini service
      final response = await _geminiService.askAboutText(
        text,
        customPrompt: prompt,
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: operation,
      );

      // Create response based on operation
      final result = {
        'success': true,
        'source': 'gemini',
        'originalText': text,
      };

      // Add operation-specific fields
      switch (operation) {
        case 'translation':
          result['translation'] = response;
          result['targetLanguage'] = targetLanguage ?? 'Spanish';
          break;

        case 'generate_image':
          result['imagePrompt'] = response;
          result['style'] = style ?? 'Realistic';
          break;

        default:
          result['response'] = response;
      }

      return result;
    } catch (e, stackTrace) {
      _logger.severe(
          'Error processing text with operation: $operation', e, stackTrace);
      return _createErrorResponse(e.toString(), operation);
    }
  }

  /// Try to fetch dictionary definition from the Dictionary API
  Future<Map<String, dynamic>> _fetchDictionaryFromApi(
      String word, String language) async {
    try {
      final url = '$_dictionaryApiUrl/$language/$word';
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return {
          'success': true,
          'source': 'dictionary-api',
          'data': data,
          'word': word,
          'language': language,
        };
      } else {
        _logger.info(
            'Dictionary API returned status code ${response.statusCode} for "$word", falling back to Gemini');
        throw Exception(
            'Word not found in dictionary (status: ${response.statusCode})');
      }
    } catch (e) {
      _logger.info('Dictionary API error: $e');
      rethrow; // Let the caller handle fallback
    }
  }

  /// Process dictionary definition with Gemini
  Future<Map<String, dynamic>> _getGeminiDefinition(
      String word,
      String language,
      String bookTitle,
      int currentPage,
      int totalPages) async {
    try {
      String languageName = _getLanguageName(language);

      final prompt = '''
Provide a dictionary definition for the word or phrase "$word" in $languageName. Include:
1. Part of speech (noun, verb, adjective, etc.)
2. Phonetic pronunciation if available
3. Multiple definitions if applicable
4. Example sentences showing usage
5. Etymology information if relevant
''';

      final response = await _geminiService.askAboutText(
        word,
        customPrompt: prompt,
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: 'dictionary_lookup',
      );

      return {
        'success': true,
        'source': 'gemini',
        'data': response,
        'word': word,
        'language': language,
      };
    } catch (e, stackTrace) {
      _logger.severe('Error getting Gemini definition', e, stackTrace);
      rethrow;
    }
  }

  /// Process Wikipedia information with Gemini
  Future<Map<String, dynamic>> _getGeminiWikipediaInfo(
      String term,
      String language,
      String bookTitle,
      int currentPage,
      int totalPages) async {
    try {
      String languageName = _getLanguageName(language);

      final prompt = '''
Provide encyclopedic information about "$term" in $languageName as if you were writing a Wikipedia article. Include:
1. A concise introduction summarizing the subject
2. The most important facts and context
3. Historical background if relevant
4. Cultural significance if applicable
Format the response as if it were a Wikipedia entry with clear sections.
''';

      final response = await _geminiService.askAboutText(
        term,
        customPrompt: prompt,
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: 'wikipedia_lookup',
      );

      return {
        'success': true,
        'source': 'gemini',
        'data': response,
        'term': term,
        'language': language,
      };
    } catch (e, stackTrace) {
      _logger.severe('Error getting Gemini Wikipedia info', e, stackTrace);
      rethrow;
    }
  }

  /// Convert language code to language name
  String _getLanguageName(String code) {
    final languageMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'vi': 'Vietnamese',
    };

    return languageMap[code.toLowerCase()] ?? code;
  }

  /// Sanitize search term by removing excess whitespace and some special characters
  String _sanitizeSearchTerm(String term) {
    return term.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Create standardized error response
  Map<String, dynamic> _createErrorResponse(
      String errorMessage, String operation) {
    return {
      'success': false,
      'error': errorMessage,
      'operation': operation,
    };
  }

  /// Handle a text selection request based on menu type
  Future<Map<String, dynamic>> handleSelection({
    required String text,
    required SelectionMenuType menuType,
    String? customPrompt,
    String? selectedOption,
    String bookTitle = 'Reading',
    int currentPage = 1,
    int totalPages = 1,
  }) async {
    switch (menuType) {
      case SelectionMenuType.askAi:
        return await _processTextWithAi(
          text: text,
          operation: 'ask_ai',
          customPrompt: customPrompt ?? '',
          bookTitle: bookTitle,
          currentPage: currentPage,
          totalPages: totalPages,
        );

      case SelectionMenuType.translate:
        return await _processTextWithAi(
          text: text,
          operation: 'translation',
          targetLanguage: selectedOption ?? 'Spanish',
          bookTitle: bookTitle,
          currentPage: currentPage,
          totalPages: totalPages,
        );

      case SelectionMenuType.dictionary:
        return await getDictionaryDefinition(text,
            language: _getLanguageCode(selectedOption ?? 'English'),
            bookTitle: bookTitle,
            currentPage: currentPage,
            totalPages: totalPages);

      case SelectionMenuType.wikipedia:
        return await getWikipediaInformation(text,
            bookTitle: bookTitle,
            currentPage: currentPage,
            totalPages: totalPages);

      case SelectionMenuType.generateImage:
        return await _processTextWithAi(
          text: text,
          operation: 'generate_image',
          style: selectedOption ?? 'Realistic',
          customPrompt: customPrompt,
          bookTitle: bookTitle,
          currentPage: currentPage,
          totalPages: totalPages,
        );

      default:
        return _createErrorResponse(
            'Unsupported operation type: ${menuType.name}', 'unknown');
    }
  }

  /// Get language code from language name
  String _getLanguageCode(String language) {
    final codeMap = {
      'English': 'en',
      'Spanish': 'es',
      'French': 'fr',
      'German': 'de',
      'Italian': 'it',
      'Portuguese': 'pt',
      'Russian': 'ru',
      'Chinese': 'zh',
      'Japanese': 'ja',
      'Arabic': 'ar',
      'Vietnamese': 'vi',
    };

    return codeMap[language] ?? 'en';
  }
}
