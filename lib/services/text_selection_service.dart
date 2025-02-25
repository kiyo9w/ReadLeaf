import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

class TextSelectionService {
  final GeminiService _geminiService = GetIt.I<GeminiService>();
  final _logger = Logger('TextSelectionService');

  // Dictionary API URL (using Free Dictionary API)
  final String _dictionaryApiUrl =
      'https://api.dictionaryapi.dev/api/v2/entries';

  // Wikipedia API URL
  final String _wikipediaApiUrl =
      'https://en.wikipedia.org/api/rest_v1/page/summary';

  // For translations, we'll use the Gemini service since it can handle multiple languages

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
      // Clean up the word - remove extra spaces, punctuation, etc.
      final cleanWord =
          word.trim().replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();

      if (cleanWord.isEmpty) {
        throw Exception('Word cannot be empty');
      }

      // Check if we should use API or Gemini based on language
      if (language == 'en') {
        // For English, we can use the free dictionary API
        final url = '$_dictionaryApiUrl/$language/$cleanWord';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          return {
            'success': true,
            'source': 'dictionary-api',
            'data': data,
            'word': cleanWord,
            'language': language,
          };
        } else if (response.statusCode == 404) {
          _logger.info('Word not found in dictionary API: $cleanWord');
          // Fall back to Gemini
          return _getGeminiDefinition(
              word, language, bookTitle, currentPage, totalPages);
        } else {
          _logger.warning(
              'Dictionary API error: ${response.statusCode} ${response.body}');
          throw Exception(
              'Failed to load definition: ${response.reasonPhrase}');
        }
      } else {
        // For non-English, use Gemini
        return _getGeminiDefinition(
            word, language, bookTitle, currentPage, totalPages);
      }
    } catch (e, stackTrace) {
      _logger.severe('Error getting dictionary definition', e, stackTrace);
      return {
        'success': false,
        'error': e.toString(),
        'word': word,
        'language': language,
      };
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
      // Clean up the term
      final cleanTerm = term.trim();
      if (cleanTerm.isEmpty) {
        throw Exception('Term cannot be empty');
      }

      // First try the Wikipedia API
      final encodedTerm = Uri.encodeComponent(cleanTerm);
      final url =
          'https://$language.wikipedia.org/api/rest_v1/page/summary/$encodedTerm';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'source': 'wikipedia-api',
          'data': data,
          'term': cleanTerm,
          'language': language,
        };
      } else if (response.statusCode == 404) {
        _logger.info('Term not found in Wikipedia API: $cleanTerm');
        // Fall back to Gemini for providing general information
        return _getGeminiWikipediaInfo(
            term, language, bookTitle, currentPage, totalPages);
      } else {
        _logger.warning(
            'Wikipedia API error: ${response.statusCode} ${response.body}');
        throw Exception(
            'Failed to load Wikipedia information: ${response.reasonPhrase}');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error getting Wikipedia information', e, stackTrace);
      return {
        'success': false,
        'error': e.toString(),
        'term': term,
        'language': language,
      };
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
    try {
      if (text.trim().isEmpty) {
        throw Exception('Text cannot be empty');
      }

      // For translation, we'll use Gemini
      final prompt =
          'Translate the following text to $targetLanguage. Only return the translation, no additional text:\n\n"""$text"""';

      final response = await _geminiService.askAboutText(
        text,
        customPrompt: prompt,
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: 'translation',
      );

      return {
        'success': true,
        'source': 'gemini',
        'translation': response,
        'originalText': text,
        'targetLanguage': targetLanguage,
      };
    } catch (e, stackTrace) {
      _logger.severe('Error translating text', e, stackTrace);
      return {
        'success': false,
        'error': e.toString(),
        'originalText': text,
        'targetLanguage': targetLanguage,
      };
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

      final prompt =
          'Provide a dictionary definition for the word or phrase "$word" in $languageName. Include:' +
              '\n1. Part of speech (noun, verb, adjective, etc.)' +
              '\n2. Phonetic pronunciation if available' +
              '\n3. Multiple definitions if applicable' +
              '\n4. Example sentences showing usage' +
              '\n5. Etymology information if relevant';

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
      throw e;
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

      final prompt =
          'Provide encyclopedic information about "$term" in $languageName as if you were writing a Wikipedia article. Include:' +
              '\n1. A concise introduction summarizing the subject' +
              '\n2. The most important facts and context' +
              '\n3. Historical background if relevant' +
              '\n4. Cultural significance if applicable' +
              '\nFormat the response as if it were a Wikipedia entry with clear sections.';

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
      throw e;
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
    };

    return languageMap[code.toLowerCase()] ?? code;
  }
}
