import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/settings/data/sync/sync_manager.dart';
import 'package:read_leaf/features/characters/data/character_template_service.dart';
import 'package:read_leaf/features/characters/data/default_character_loader.dart';
import 'package:read_leaf/features/characters/data/public_character_repository.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Add stream controller for character updates
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
        final publicCharacters = await _loadPublicCharacters();
        _log.info('Loaded ${publicCharacters.length} public characters');
        _publicCharacters = publicCharacters;

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

  Future<List<AiCharacter>> _loadPublicCharacters() async {
    try {
      // Get public characters from repository
      final publicCharacters =
          await _publicCharacterRepository.getAllPublicCharacters(
        limit: 100,
        sortBy: 'created_at',
        descending: true,
      );

      // Convert to AiCharacter objects
      return publicCharacters.map((pc) => pc.toAiCharacter()).toList();
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

      // Convert to AiCharacter objects
      final categoryCharacters =
          publicCharacters.map((pc) => pc.toAiCharacter()).toList();

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

  Future<void> addCustomCharacter(AiCharacter character,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      _log.info('Adding custom character: ${character.name}');

      // Save to template service
      await _templateService.saveTemplate(
        character,
        isPublic: isPublic,
        category: category,
      );

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

  Future<void> updateCharacter(AiCharacter character,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      await _templateService.saveTemplate(
        character,
        isPublic: isPublic,
        category: category,
      );

      // Update selected character if it's the same one
      if (_selectedCharacter?.name == character.name) {
        _selectedCharacter = character;
      }

      // Update local list
      _characters = [
        character,
        ..._characters.where((c) => c.name != character.name),
      ];

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
      await _templateService.deleteTemplate(name);

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
      await _templateService.updateTemplatePublicity(
        name,
        isPublic,
        category: category,
      );

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

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'character_preferences', json.encode(_characterPreferences));
    } catch (e, stack) {
      _log.warning('Error updating preference from server', e, stack);
      // Non-fatal error
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
