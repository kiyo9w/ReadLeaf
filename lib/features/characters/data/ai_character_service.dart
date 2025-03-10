import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/settings/data/sync/sync_manager.dart';
import 'package:read_leaf/features/characters/data/character_template_service.dart';
import 'package:read_leaf/features/characters/data/default_character_loader.dart';
import 'package:read_leaf/features/characters/data/public_character_repository.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';

class AiCharacterService {
  static final _log = Logger('AiCharacterService');
  late final CharacterTemplateService _templateService;
  late final SyncManager _syncManager;
  late final PublicCharacterRepository _publicCharacterRepository;
  AiCharacter? _selectedCharacter;
  final Map<String, Map<String, dynamic>> _characterPreferences = {};
  List<AiCharacter> _characters = [];
  List<AiCharacter> _publicCharacters = [];

  // Stream controller for character updates
  final _characterUpdateController = StreamController<void>.broadcast();
  Stream<void> get onCharacterUpdate => _characterUpdateController.stream;

  Future<void> init() async {
    try {
      _log.info('Initializing AiCharacterService');
      _templateService = CharacterTemplateService();
      _syncManager = GetIt.I<SyncManager>();
      _publicCharacterRepository = PublicCharacterRepository();

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
          orElse: () => _characters[0],
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

      // Save selection to server if authenticated
      if (_syncManager.isAuthenticated) {
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
      }

      // Store preferences locally for all characters, not just community ones
      await _saveCharacterPreference(character.name);

      // Notify listeners of the update
      _characterUpdateController.add(null);
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

      // Load public characters regardless of authentication status
      List<AiCharacter> publicCharacters = [];
      try {
        publicCharacters = await _loadPublicCharacters();
        _log.info('Loaded ${publicCharacters.length} public characters');
        _publicCharacters = publicCharacters;
      } catch (e) {
        _log.warning('Error loading public characters: $e');
        publicCharacters = [];
      }

      // Start with defaults + publics for all users
      Map<String, AiCharacter> combinedCharacters = {
        ...Map.fromEntries(defaultCharacters.map((c) => MapEntry(c.name, c))),
        ...Map.fromEntries(publicCharacters.map((c) => MapEntry(c.name, c))),
      };

      // If authenticated, add user's custom characters
      if (_syncManager.isAuthenticated) {
        try {
          final customCharacters = await _templateService.getUserTemplates();
          _log.info('Loaded ${customCharacters.length} custom characters');

          // Add custom characters to the combined map
          combinedCharacters.addAll(
            Map.fromEntries(customCharacters.map((c) => MapEntry(c.name, c))),
          );
        } catch (e) {
          _log.warning('Error loading custom characters: $e');
        }
      }

      final allCharacters = combinedCharacters.values.toList();
      _characters = allCharacters;
      _log.info('Returning ${allCharacters.length} total characters');
      return allCharacters;
    } catch (e, stack) {
      _log.severe('Error getting all characters', e, stack);
      // Return empty list as last resort
      _characters = [];
      return [];
    }
  }

  Future<List<AiCharacter>> _loadPublicCharacters() async {
    try {
      // Get public characters from repository
      final publicCharacters =
          await _publicCharacterRepository.getAllPublicCharacters(
        limit: 100,
        sortBy: 'created_at',
        descending: true, // Ensure newest characters show first
      );

      // Convert to AiCharacter objects and add Community tag
      return publicCharacters.map((pc) {
        final character = pc.toAiCharacter();
        // Add a special tag that this is from the community
        if (!character.tags.contains('Community')) {
          return character.copyWith(
            tags: [...character.tags, 'Community'],
          );
        }
        return character;
      }).toList();
    } catch (e, stack) {
      _log.severe('Error loading public characters', e, stack);
      return [];
    }
  }

  Future<List<AiCharacter>> getCharactersByCategory(String category) async {
    if (category == 'All') {
      return _characters;
    }

    if (category == 'Custom') {
      return _characters.where((c) => c.tags.contains('Custom')).toList();
    }

    try {
      // Get characters from the public repository by category
      final publicCharacters =
          await _publicCharacterRepository.getPublicCharactersByCategory(
        category,
        limit: 50,
      );

      // Convert to AiCharacter objects and add Community tag
      final categoryCharacters = publicCharacters.map((pc) {
        final character = pc.toAiCharacter();
        if (!character.tags.contains('Community')) {
          return character.copyWith(
            tags: [...character.tags, 'Community'],
          );
        }
        return character;
      }).toList();

      // Add any local characters with matching tags
      final localCategoryCharacters = _characters
          .where((c) =>
              c.tags.contains(category) &&
              !categoryCharacters.any((pc) => pc.name == c.name))
          .toList();

      return [...categoryCharacters, ...localCategoryCharacters];
    } catch (e, stack) {
      _log.severe('Error getting characters by category', e, stack);
      // Fall back to local filtering
      return _characters.where((c) => c.tags.contains(category)).toList();
    }
  }

  List<AiCharacter> getCharactersSync() {
    return _characters;
  }

  /// Get only user-selected characters sorted by last used time
  List<AiCharacter> getUserSelectedCharacters() {
    try {
      // Start with built-in default characters
      final defaultCharacters = _characters
          .where((c) =>
              !c.tags.contains('Community') ||
              _characterPreferences.containsKey(c.name))
          .toList();

      // Sort by last used time if we have preferences
      if (_characterPreferences.isNotEmpty) {
        defaultCharacters.sort((a, b) {
          final aLastUsed = _characterPreferences[a.name]?['last_used'];
          final bLastUsed = _characterPreferences[b.name]?['last_used'];

          if (aLastUsed == null && bLastUsed == null) return 0;
          if (aLastUsed == null) return 1; // b comes first
          if (bLastUsed == null) return -1; // a comes first

          // Compare timestamps, newer first
          return DateTime.parse(bLastUsed).compareTo(DateTime.parse(aLastUsed));
        });
      }

      _log.info(
          'Returning ${defaultCharacters.length} user-selected characters');
      return defaultCharacters;
    } catch (e) {
      _log.warning('Error getting user-selected characters: $e');
      // Return empty list as fallback
      return _characters.where((c) => !c.tags.contains('Community')).toList();
    }
  }

  Future<void> addCustomCharacter(AiCharacter character,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      _log.info('Adding custom character: ${character.name}');

      // Add to local list first for immediate feedback
      _characters = [
        character,
        ..._characters.where((c) => c.name != character.name),
      ];

      // Only try saving to server if user is authenticated
      if (_syncManager.isAuthenticated) {
        try {
          await _templateService.saveTemplate(
            character,
            isPublic: isPublic,
            category: category,
          );
          _log.info('Successfully saved character to server');
        } catch (e) {
          // If it's a duplicate, just continue with local version
          if (e is PostgrestException && e.code == '23505') {
            _log.info(
                'Character already exists in database. Using local version.');
          } else {
            _log.warning('Failed to save character to server: $e');
          }
        }
      }

      // Update selected character if none is selected
      if (_selectedCharacter == null) {
        _selectedCharacter = character;
        _log.info('Setting new character as selected');
      }

      // Save to local preferences
      await _saveCharacterPreference(character.name);

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info('Successfully added character: ${character.name}');
    } catch (e, stack) {
      _log.severe('Error adding custom character', e, stack);
      rethrow;
    }
  }

  Future<void> updateCharacter(AiCharacter character,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      // Try to save to server if authenticated
      if (_syncManager.isAuthenticated) {
        await _templateService.saveTemplate(
          character,
          isPublic: isPublic,
          category: category,
        );
      }

      // Update selected character if it's the same one
      if (_selectedCharacter?.name == character.name) {
        _selectedCharacter = character;
      }

      // Update local list
      _characters = [
        character,
        ..._characters.where((c) => c.name != character.name),
      ];

      // Save to local preferences
      await _saveCharacterPreference(character.name);

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info('Updated character: ${character.name}');
    } catch (e, stack) {
      _log.severe('Error updating character', e, stack);
      rethrow;
    }
  }

  Future<void> deleteCharacter(String name) async {
    try {
      // Try to delete from server if authenticated
      if (_syncManager.isAuthenticated) {
        await _templateService.deleteTemplate(name);
      }

      // If deleted character was selected, switch to default
      if (_selectedCharacter?.name == name) {
        final defaultCharacters =
            await DefaultCharacterLoader.loadDefaultCharacters();
        _selectedCharacter = defaultCharacters.firstWhere(
          (c) => c.name == 'Amelia',
          orElse: () => defaultCharacters[0],
        );
      }

      // Remove from local list
      _characters = _characters.where((c) => c.name != name).toList();

      // Remove from preferences
      _characterPreferences.remove(name);
      await _saveAllPreferences();

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info('Deleted character: $name');
    } catch (e, stack) {
      _log.severe('Error deleting character', e, stack);
      rethrow;
    }
  }

  Future<void> importCharacter(String jsonPath,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      final character = await _templateService.importTemplate(jsonPath);
      await addCustomCharacter(
        character,
        isPublic: isPublic,
        category: category,
      );
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

  Future<void> updateCharacterPublicity(String name, bool isPublic,
      {String category = 'Custom'}) async {
    try {
      if (_syncManager.isAuthenticated) {
        await _templateService.updateTemplatePublicity(
          name,
          isPublic,
          category: category,
        );
      }

      // Refresh the character list
      await getAllCharacters();

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info('Updated character publicity: $name, isPublic: $isPublic');
    } catch (e, stack) {
      _log.severe('Error updating character publicity', e, stack);
      rethrow;
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString('character_preferences');
      if (prefsJson != null) {
        final prefsMap = json.decode(prefsJson) as Map<String, dynamic>;
        _characterPreferences.clear();
        prefsMap.forEach((key, value) {
          _characterPreferences[key] = value as Map<String, dynamic>;
        });
      }

      // Try to load selected character from preferences
      final selectedCharName = prefs.getString('selected_character');
      if (selectedCharName != null && _characters.isNotEmpty) {
        _selectedCharacter = _characters.firstWhere(
          (c) => c.name == selectedCharName,
          orElse: () => _characters[0],
        );
      }
    } catch (e, stack) {
      _log.warning('Error loading preferences', e, stack);
      // Non-fatal error, continue with defaults
    }
  }

  // Helper method to save a character preference
  Future<void> _saveCharacterPreference(String characterName) async {
    try {
      // Store preferences locally
      _characterPreferences[characterName] = {
        'last_used': DateTime.now().toIso8601String(),
        'custom_settings': {},
      };

      await _saveAllPreferences();
    } catch (e) {
      _log.warning('Failed to save character preference: $e');
    }
  }

  // Helper method to save all preferences
  Future<void> _saveAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'character_preferences', json.encode(_characterPreferences));

      // Also save selected character if we have one
      if (_selectedCharacter != null) {
        await prefs.setString('selected_character', _selectedCharacter!.name);
      }
    } catch (e) {
      _log.warning('Failed to save preferences: $e');
    }
  }

  Future<void> updatePreferenceFromServer(
    String characterName,
    DateTime lastUsed,
    Map<String, dynamic> customSettings,
  ) async {
    try {
      _characterPreferences[characterName] = {
        'last_used': lastUsed.toIso8601String(),
        'custom_settings': customSettings,
      };

      await _saveAllPreferences();
    } catch (e, stack) {
      _log.warning('Error updating preference from server', e, stack);
      // Non-fatal error
    }
  }

  Future<AiCharacter> addPublicCharacterToCollection(String characterId) async {
    try {
      _log.info('Adding public character to local collection: $characterId');

      // Get the character from the public repository
      final character =
          await _publicCharacterRepository.getPublicCharacterById(characterId);

      if (character == null) {
        throw Exception('Character not found');
      }

      final aiCharacter = character.toAiCharacter();

      // Add the 'Community' tag if not present
      List<String> updatedTags = [...aiCharacter.tags];
      if (!updatedTags.contains('Community')) {
        updatedTags.add('Community');
      }

      final updatedCharacter = aiCharacter.copyWith(tags: updatedTags);

      // Add to local list, replacing any existing character with same name
      _characters = [
        updatedCharacter,
        ..._characters.where((c) => c.name != updatedCharacter.name),
      ];

      // Increment the download count on the server
      if (_syncManager.isAuthenticated) {
        try {
          await _publicCharacterRepository.incrementDownloadCount(characterId);
          _log.info('Incremented download count for character: $characterId');
        } catch (e) {
          _log.warning('Failed to increment download count: $e');
        }
      }

      // Save to local preferences
      await _saveCharacterPreference(updatedCharacter.name);

      // Notify listeners of the update
      _characterUpdateController.add(null);

      _log.info(
          'Added public character to collection: ${updatedCharacter.name}');
      return updatedCharacter;
    } catch (e, stack) {
      _log.severe('Error adding public character to collection', e, stack);
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

  void dispose() {
    _characterUpdateController.close();
  }
}
