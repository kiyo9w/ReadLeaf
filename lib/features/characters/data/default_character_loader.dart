import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:logging/logging.dart';

class DefaultCharacterLoader {
  static final _log = Logger('DefaultCharacterLoader');
  static const _defaultCharactersPath = 'lib/features/characters/data/default_characters.json';
  static List<AiCharacter>? _cachedCharacters;

  /// Load default character templates from the JSON file
  static Future<List<AiCharacter>> loadDefaultCharacters() async {
    try {
      // Return cached characters if available
      if (_cachedCharacters != null) {
        _log.info('Returning ${_cachedCharacters!.length} cached characters');
        return _cachedCharacters!;
      }

      _log.info('Loading default characters from $_defaultCharactersPath');

      // Load and parse the JSON file
      final jsonString = await rootBundle.loadString(_defaultCharactersPath);
      if (jsonString.isEmpty) {
        throw Exception('Default characters file is empty');
      }
      _log.info('Successfully loaded JSON file');

      final json = jsonDecode(jsonString);
      if (json == null) {
        throw Exception('Failed to parse JSON');
      }
      _log.info('Successfully parsed JSON');

      if (!json.containsKey('characters')) {
        throw Exception('Invalid JSON format: missing "characters" key');
      }

      final charactersList = json['characters'] as List;
      if (charactersList.isEmpty) {
        throw Exception('No characters found in JSON');
      }

      // Convert JSON to AiCharacter objects
      final characters = charactersList
          .map((charJson) {
            try {
              final Map<String, dynamic> characterData =
                  charJson.containsKey('data') ? charJson['data'] : charJson;
              return AiCharacter.fromJson(characterData);
            } catch (e) {
              _log.warning('Failed to parse character: $e');
              return null;
            }
          })
          .whereType<AiCharacter>() // Filter out nulls
          .toList();

      if (characters.isEmpty) {
        throw Exception('No valid characters could be parsed from JSON');
      }

      // Cache the characters
      _cachedCharacters = characters;

      _log.info('Successfully loaded ${characters.length} default characters');
      return characters;
    } catch (e, stack) {
      _log.severe('Error loading default characters', e, stack);
      // Return empty list on error
      return [];
    }
  }

  /// Get a specific default character by name
  static Future<AiCharacter?> getDefaultCharacter(String name) async {
    try {
      final characters = await loadDefaultCharacters();
      return characters.firstWhere(
        (char) => char.name == name,
        orElse: () => throw Exception('Character not found: $name'),
      );
    } catch (e) {
      _log.warning('Error getting default character: $name', e);
      return null;
    }
  }

  /// Clear the character cache
  static void clearCache() {
    _cachedCharacters = null;
    _log.info('Default character cache cleared');
  }

  /// Validate all default characters
  static Future<List<String>> validateDefaultCharacters() async {
    final errors = <String>[];
    try {
      final characters = await loadDefaultCharacters();

      for (final character in characters) {
        final error = AiCharacter.validate(
          name: character.name,
          summary: character.summary,
          personality: character.personality,
          scenario: character.scenario,
          greetingMessage: character.greetingMessage,
          exampleMessages: character.exampleMessages,
          avatarImagePath: character.avatarImagePath,
        );

        if (error != null) {
          errors.add('${character.name}: $error');
        }
      }
    } catch (e) {
      errors.add('Error validating characters: $e');
    }

    return errors;
  }
}
