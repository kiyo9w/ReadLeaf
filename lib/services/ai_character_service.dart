import 'package:flutter/material.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/services/sync/sync_manager.dart';
import 'package:read_leaf/services/character_template_service.dart';
import 'package:read_leaf/services/default_character_loader.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class AiCharacterService {
  static final _log = Logger('AiCharacterService');
  late final CharacterTemplateService _templateService;
  late final SyncManager _syncManager;
  AiCharacter? _selectedCharacter;
  final Map<String, Map<String, dynamic>> _characterPreferences = {};
  List<AiCharacter> _characters = [];

  // Add stream controller for character updates
  final _characterUpdateController = StreamController<void>.broadcast();
  Stream<void> get onCharacterUpdate => _characterUpdateController.stream;

  Future<void> init() async {
    try {
      _log.info('Initializing AiCharacterService');
      _templateService = CharacterTemplateService();
      _syncManager = GetIt.I<SyncManager>();

      // First load default characters to ensure we have something
      final defaultCharacters =
          await DefaultCharacterLoader.loadDefaultCharacters();
      if (defaultCharacters.isEmpty) {
        _log.severe('Failed to load default characters');
        throw Exception('Failed to load default characters');
      }
      _characters = defaultCharacters;
      _log.info('Loaded ${defaultCharacters.length} default characters');

      // Try to load all characters (including custom and public)
      try {
        _characters = await getAllCharacters();
        _log.info('Loaded ${_characters.length} total characters');
      } catch (e) {
        _log.warning(
            'Failed to load all characters, falling back to defaults', e);
        _characters = defaultCharacters;
      }

      // Load preferences from local storage
      await _loadPreferences();

      // Set default character if none selected
      if (_selectedCharacter == null && _characters.isNotEmpty) {
        // Try to find Amelia first
        _selectedCharacter = _characters.firstWhere(
          (c) => c.name == 'Amelia',
          orElse: () =>
              _characters[0], // If Amelia not found, use first character
        );
        _log.info('Selected default character: ${_selectedCharacter?.name}');
      }
    } catch (e, stack) {
      _log.severe('Error initializing AiCharacterService', e, stack);
      rethrow;
    }
  }

  Future<void> setSelectedCharacter(AiCharacter character) async {
    try {
      _selectedCharacter = character;

      // Save selection to server
      await _syncManager.syncCharacterPreferences(
        character.name,
        {
          'character_name': character.name,
          'last_used': DateTime.now().toIso8601String(),
          'custom_settings': character.tags.contains('Custom')
              ? {
                  'personality': character.personality,
                  'summary': character.summary,
                  'scenario': character.scenario,
                  'greeting_message': character.greetingMessage,
                  'system_prompt': character.systemPrompt,
                }
              : {},
        },
      );
    } catch (e, stack) {
      _log.severe('Error setting selected character', e, stack);
      rethrow;
    }
  }

  AiCharacter? getSelectedCharacter() {
    return _selectedCharacter;
  }

  Future<List<AiCharacter>> getAllCharacters() async {
    try {
      _log.info('Loading all characters');

      // Get default characters first
      final defaultCharacters =
          await DefaultCharacterLoader.loadDefaultCharacters();
      _log.info('Loaded ${defaultCharacters.length} default characters');

      // If not authenticated, return only default characters
      if (_syncManager.isAuthenticated != true) {
        _log.info('User not authenticated, returning only default characters');
        _characters = defaultCharacters;
        return defaultCharacters;
      }

      try {
        // Get user's custom characters
        final customCharacters = await _templateService.getUserTemplates();
        _log.info('Loaded ${customCharacters.length} custom characters');

        // Get public characters
        final publicCharacters = await _templateService.getPublicTemplates();
        _log.info('Loaded ${publicCharacters.length} public characters');

        // Combine all characters, removing duplicates by name
        final allCharacters = {
          ...Map.fromEntries(defaultCharacters.map((c) => MapEntry(c.name, c))),
          ...Map.fromEntries(customCharacters.map((c) => MapEntry(c.name, c))),
          ...Map.fromEntries(publicCharacters.map((c) => MapEntry(c.name, c))),
        }.values.toList();

        _characters = allCharacters;
        _log.info('Returning ${allCharacters.length} total characters');
        return allCharacters;
      } catch (e) {
        _log.warning('Error getting custom/public characters: $e');
        // Return default characters if custom/public character fetch fails
        _characters = defaultCharacters;
        return defaultCharacters;
      }
    } catch (e, stack) {
      _log.severe('Error getting all characters', e, stack);
      // Return empty list as last resort
      _characters = [];
      return [];
    }
  }

  Future<void> addCustomCharacter(AiCharacter character) async {
    try {
      _log.info('Adding custom character: ${character.name}');

      // Save to template service
      await _templateService.saveTemplate(character);

      // Add to local list
      _characters = [
        character,
        ..._characters.where((c) => c.name != character.name),
      ];

      // Update selected character if none is selected
      if (_selectedCharacter == null) {
        _selectedCharacter = character;
        _log.info('Setting newly created character as selected');
      }

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info('Successfully added custom character: ${character.name}');
    } catch (e, stack) {
      _log.severe('Error adding custom character', e, stack);
      rethrow;
    }
  }

  Future<void> updateCharacter(AiCharacter character) async {
    try {
      await _templateService.saveTemplate(character);

      // Update selected character if it's the same one
      if (_selectedCharacter?.name == character.name) {
        _selectedCharacter = character;
      }

      _log.info('Updated character: ${character.name}');
    } catch (e, stack) {
      _log.severe('Error updating character', e, stack);
      rethrow;
    }
  }

  Future<void> deleteCharacter(String name) async {
    try {
      await _templateService.deleteTemplate(name);

      // If deleted character was selected, switch to default
      if (_selectedCharacter?.name == name) {
        final defaultCharacters =
            await DefaultCharacterLoader.loadDefaultCharacters();
        _selectedCharacter = defaultCharacters[2]; // Default to Amelia
      }

      _log.info('Deleted character: $name');
    } catch (e, stack) {
      _log.severe('Error deleting character', e, stack);
      rethrow;
    }
  }

  Future<void> importCharacter(String jsonPath) async {
    try {
      final character = await _templateService.importTemplate(jsonPath);
      await addCustomCharacter(character);
      _log.info('Imported character: ${character.name}');
    } catch (e, stack) {
      _log.severe('Error importing character', e, stack);
      rethrow;
    }
  }

  Future<String> exportCharacter(AiCharacter character) async {
    try {
      final path = await _templateService.exportTemplate(character);
      _log.info('Exported character ${character.name} to $path');
      return path;
    } catch (e, stack) {
      _log.severe('Error exporting character', e, stack);
      rethrow;
    }
  }

  String getPromptTemplate() {
    return _selectedCharacter?.getEffectiveSystemPrompt() ??
        _getDefaultPromptTemplate();
  }

  String _getDefaultPromptTemplate() {
    return """You are a creative and intelligent AI assistant engaged in an iterative storytelling experience.

ROLEPLAY RULES:
- Keep responses personal and in-character
- Use subtle physical cues to hint at mental state
- Include internal thoughts in asterisks *like this*
- Keep responses concise (2-3 sentences)
- Stay in character at all times
- Express emotions and reactions naturally""";
  }

  @override
  Future<void> dispose() async {
    _log.info('Disposing AiCharacterService');
    DefaultCharacterLoader.clearCache();
    await _characterUpdateController.close();
  }

  Future<void> updatePreferenceFromServer(
    String characterName,
    DateTime lastUsed,
    Map<String, dynamic> customSettings,
  ) async {
    try {
      // Find the character in our loaded characters
      final character = _characters.firstWhere(
        (c) => c.name == characterName,
        orElse: () => throw Exception('Character not found: $characterName'),
      );

      // Update preferences
      _characterPreferences[characterName] = {
        'lastUsed': lastUsed.toIso8601String(),
        'customSettings': customSettings,
      };

      // If this is the currently selected character, update its settings
      if (_selectedCharacter?.name == characterName) {
        _selectedCharacter = character;
      }

      await _savePreferences();
      _log.info('Updated preferences for character: $characterName');
    } catch (e, stack) {
      _log.severe('Error updating character preferences', e, stack);
      rethrow;
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = jsonEncode(_characterPreferences);
      await prefs.setString('character_preferences', prefsJson);
      _log.info('Saved character preferences to local storage');
    } catch (e, stack) {
      _log.severe('Error saving character preferences', e, stack);
      rethrow;
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString('character_preferences');
      if (prefsJson != null) {
        final Map<String, dynamic> prefsMap = jsonDecode(prefsJson);
        _characterPreferences.clear();
        prefsMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _characterPreferences[key] = value;
          }
        });
        _log.info('Loaded character preferences from local storage');
      }
    } catch (e, stack) {
      _log.severe('Error loading character preferences', e, stack);
      // Don't rethrow - allow service to continue with empty preferences
    }
  }

  List<AiCharacter> getCharactersSync() {
    return _characters;
  }
}
