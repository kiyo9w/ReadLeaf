import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:read_leaf/features/characters/data/public_character_repository.dart';

class CharacterTemplateService {
  final _log = Logger('CharacterTemplateService');
  final _supabase = Supabase.instance.client;
  static const _templateDir = 'character_templates';
  late final PublicCharacterRepository _publicCharacterRepository;

  CharacterTemplateService() {
    _publicCharacterRepository = PublicCharacterRepository();
  }

  // Get local template directory
  Future<Directory> get _localTemplateDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final templateDir = Directory(path.join(appDir.path, _templateDir));
    if (!await templateDir.exists()) {
      await templateDir.create(recursive: true);
    }
    return templateDir;
  }

  // Import a character template from JSON file
  Future<AiCharacter> importTemplate(String jsonPath) async {
    try {
      _log.info('Starting import from path: $jsonPath');

      final file = File(jsonPath);
      if (!await file.exists()) {
        _log.severe('File not found at path: $jsonPath');
        throw Exception('Template file not found');
      }

      final jsonString = await file.readAsString();
      _log.info(
          'Raw JSON content (first 500 chars): ${jsonString.length > 500 ? jsonString.substring(0, 500) : jsonString}...');

      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      _log.info('Decoded JSON structure keys: ${jsonMap.keys.join(', ')}');

      // If JSON is wrapped in a "data" key, use it; otherwise, use as is
      final Map<String, dynamic> rawCharacterJson = jsonMap.containsKey('data')
          ? jsonMap['data'] as Map<String, dynamic>
          : jsonMap;
      _log.info('Raw character JSON keys: ${rawCharacterJson.keys.join(', ')}');

      // Create a new map with processed fields
      _log.info('Processing fields...');
      final Map<String, dynamic> characterJson = {};

      // Process each field individually with logging
      try {
        characterJson['name'] =
            _getStringValue(rawCharacterJson, ['name', 'char_name']);
        _log.info('Processed name: ${characterJson['name']}');

        // Handle description field
        final description =
            _getStringValue(rawCharacterJson, ['description'], required: true);

        // Parse description if it's JSON
        if (description != null && description.trim().startsWith('{')) {
          try {
            final Map<String, dynamic> descriptionJson =
                json.decode(description);
            // Extract the summary from the description
            final List<String> summaryParts = [];

            // Try to get the summary from different possible fields
            if (descriptionJson.containsKey('Summary')) {
              summaryParts.add(descriptionJson['Summary']);
            } else if (descriptionJson.containsKey('Character')) {
              summaryParts.add(descriptionJson['Character']);
            }

            // Store the full description as personality
            characterJson['personality'] = description;
            // Use the extracted summary or the first part of description
            characterJson['summary'] = summaryParts.isNotEmpty
                ? summaryParts.first
                : description.split('\n').first;

            _log.info('Successfully parsed description JSON');
          } catch (e) {
            _log.warning('Failed to parse description JSON: $e');
            characterJson['summary'] = description.split('\n').first;
            characterJson['personality'] = description;
          }
        } else if (description != null) {
          characterJson['summary'] = description.split('\n').first;
          characterJson['personality'] = description;
        } else {
          characterJson['summary'] = 'No description available';
          characterJson['personality'] = '';
        }
        _log.info('Processed description into summary and personality');

        final tags = _processTags(rawCharacterJson);
        characterJson['tags'] = tags;
        _log.info('Processed tags: ${tags.join(", ")}');

        characterJson['scenario'] =
            _getStringValue(rawCharacterJson, ['scenario']);
        final scenarioPreview = characterJson['scenario']?.toString() ?? '';
        _log.info(
            'Processed scenario: ${scenarioPreview.length > 50 ? "${scenarioPreview.substring(0, 50)}..." : scenarioPreview}');

        characterJson['greeting_message'] = _getStringValue(
            rawCharacterJson, ['first_mes', 'alternate_greetings']);
        final greetingPreview =
            characterJson['greeting_message']?.toString() ?? '';
        _log.info(
            'Processed greeting: ${greetingPreview.length > 50 ? "${greetingPreview.substring(0, 50)}..." : greetingPreview}');

        characterJson['example_messages'] =
            _processExampleMessages(rawCharacterJson);
        _log.info(
            'Processed example messages count: ${(characterJson['example_messages'] as List).length}');

        final avatarUrl = _getStringValue(
            rawCharacterJson, ['avatar', 'avatar_image_path'],
            required: false);
        characterJson['avatar_image_path'] =
            avatarUrl ?? 'assets/images/ai_characters/default_avatar.png';
        _log.info(
            'Processed avatar URL: ${characterJson['avatar_image_path']}');

        characterJson['character_version'] = _getStringValue(
                rawCharacterJson, ['character_version'],
                required: false) ??
            '1.0.0';
        _log.info('Processed version: ${characterJson['character_version']}');

        characterJson['system_prompt'] = _getStringValue(
                rawCharacterJson, ['system_prompt'],
                required: false) ??
            '';
        _log.info(
            'Processed system prompt length: ${characterJson['system_prompt']?.length ?? 0}');

        characterJson['creator'] =
            _getStringValue(rawCharacterJson, ['creator'], required: false) ??
                'User';
        _log.info('Processed creator: ${characterJson['creator']}');

        characterJson['created_at'] = _getStringValue(
                rawCharacterJson, ['created_at'],
                required: false) ??
            DateTime.now().toIso8601String();
        _log.info('Processed created_at: ${characterJson['created_at']}');

        characterJson['updated_at'] = _getStringValue(
                rawCharacterJson, ['updated_at'],
                required: false) ??
            DateTime.now().toIso8601String();
        _log.info('Processed updated_at: ${characterJson['updated_at']}');
      } catch (e) {
        _log.severe('Error during field processing: $e');
        rethrow;
      }

      _log.info('All fields processed. Creating AiCharacter instance...');
      _log.info('Final characterJson keys: ${characterJson.keys.join(', ')}');
      _log.info(
          'Final characterJson values types: ${characterJson.map((k, v) => MapEntry(k, v.runtimeType))}');

      try {
        final character = AiCharacter.fromJson(characterJson);
        _log.info('Successfully created AiCharacter instance');

        // Copy avatar image to local storage if it's not already there
        if (!character.avatarImagePath.startsWith('assets/')) {
          if (character.avatarImagePath.startsWith('http')) {
            // Keep network URLs as is
            _log.info(
                'Using network URL for avatar: ${character.avatarImagePath}');
            return character;
          }

          final avatarFile = File(character.avatarImagePath);
          if (await avatarFile.exists()) {
            final templateDir = await _localTemplateDir;
            final newPath = path.join(
              templateDir.path,
              'avatars',
              '${character.name}_${DateTime.now().millisecondsSinceEpoch}${path.extension(character.avatarImagePath)}',
            );
            await Directory(path.dirname(newPath)).create(recursive: true);
            await avatarFile.copy(newPath);
            return character.copyWith(avatarImagePath: newPath);
          } else {
            return character.copyWith(
                avatarImagePath:
                    'assets/images/ai_characters/default_avatar.png');
          }
        }

        return character;
      } catch (e) {
        _log.severe('Error creating AiCharacter from JSON: $e');
        _log.severe('Character JSON that failed: $characterJson');
        rethrow;
      }
    } catch (e, stack) {
      _log.severe('Error importing template: ${e.toString()}', e, stack);
      rethrow;
    }
  }

  String? _getStringValue(Map<String, dynamic> json, List<String> keys,
      {bool required = true}) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key].toString();
      }
    }
    if (required) {
      throw Exception('Missing required field: one of ${keys.join(", ")}');
    }
    return null;
  }

  List<String> _processExampleMessages(Map<String, dynamic> json) {
    try {
      final messages = json['example_messages'] ?? json['mes_example'];
      if (messages == null) return [];

      if (messages is String) {
        return messages
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (messages is List) {
        return messages
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      _log.warning('Error processing example messages: $e');
      return [];
    }
  }

  List<String> _processTags(Map<String, dynamic> json) {
    try {
      final tags = json['tags'];
      if (tags == null) return [];

      if (tags is String) {
        return tags
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (tags is List) {
        return tags
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }

      return [];
    } catch (e) {
      _log.warning('Error processing tags: $e');
      return [];
    }
  }

  // Export a character template to JSON file
  Future<String> exportTemplate(AiCharacter character) async {
    try {
      final templateDir = await _localTemplateDir;
      final fileName =
          '${character.name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path.join(templateDir.path, fileName));

      final jsonData = {
        "spec": "chara_card_v2",
        "spec_version": "2.0",
        "data": character.toJson(),
      };
      await file.writeAsString(jsonEncode(jsonData));

      return file.path;
    } catch (e, stack) {
      _log.severe('Error exporting template', e, stack);
      rethrow;
    }
  }

  // Save template to Supabase
  Future<void> saveTemplate(AiCharacter character,
      {bool isPublic = false, String category = 'Custom'}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Log the operation
      _log.info(
          'Saving character template: ${character.name}, isPublic: $isPublic, category: $category');

      // Make sure the characters table exists and can be accessed
      try {
        await _supabase.from('characters').select().limit(1);
        _log.info('Successfully connected to characters table');
      } catch (e) {
        _log.severe('Error accessing characters table: $e');
        throw Exception('Could not access characters table: $e');
      }

      // Create task prompts to JSONB
      final taskPrompts = {
        'greeting': character.greetingMessage,
        'summary': character.summary,
        'scenario': character.scenario,
      };

      try {
        // Save to unified characters table
        await _supabase.from('characters').upsert({
          'user_id': userId,
          'name': character.name,
          'summary': character.summary,
          'personality': character.personality,
          'scenario': character.scenario,
          'greeting_message': character.greetingMessage,
          'example_messages': character.exampleMessages,
          'avatar_image_path': character.avatarImagePath,
          'character_version': character.characterVersion,
          'system_prompt': character.systemPrompt,
          'tags': character.tags,
          'creator': character.creator,
          'is_public': isPublic,
          'is_template': true, // Mark as a template
          'category': category,
          'task_prompts': taskPrompts,
          'created_at': character.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        _log.info('Successfully saved character to unified characters table');
      } catch (e) {
        // Check if this is a unique constraint violation
        if (e is PostgrestException && e.code == '23505') {
          _log.info(
              'Character ${character.name} already exists for this user. Fetching from server.');

          // Instead of throwing an error, fetch the existing character
          final existingCharacter = await _supabase
              .from('characters')
              .select()
              .eq('user_id', userId)
              .eq('name', character.name)
              .single();

          _log.info(
              'Successfully fetched existing character: ${existingCharacter['name']}');

          // If the character's publicity settings differ from what the user wanted,
          // update the server's record to match the user's desired settings
          if (existingCharacter['is_public'] != isPublic ||
              existingCharacter['category'] != category) {
            _log.info('Updating existing character publicity settings');

            await _supabase
                .from('characters')
                .update({
                  'is_public': isPublic,
                  'category': category,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', userId)
                .eq('name', character.name);

            _log.info('Successfully updated character publicity settings');
          }
        } else {
          // For other errors, rethrow
          _log.severe('Error saving character to unified characters table: $e');
          rethrow;
        }
      }
    } catch (e, stack) {
      _log.severe('Error saving template', e, stack);
      rethrow;
    }
  }

  // Get user's templates
  Future<List<AiCharacter>> getUserTemplates() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Query the unified characters table for the user's templates
      final response = await _supabase
          .from('characters')
          .select()
          .eq('user_id', userId)
          .eq('is_template', true);

      return (response as List).map((json) {
        // Process any fields that might need conversion
        return _convertToAiCharacter(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting user templates', e, stack);
      rethrow;
    }
  }

  // Get public templates
  Future<List<AiCharacter>> getPublicTemplates() async {
    try {
      // Query the unified characters table for public templates
      final response = await _supabase
          .from('characters')
          .select()
          .eq('is_public', true)
          .eq('is_template', true);

      return (response as List).map((json) {
        return _convertToAiCharacter(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting public templates', e, stack);
      rethrow;
    }
  }

  // Delete template
  Future<void> deleteTemplate(String name) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Delete from unified characters table
      await _supabase
          .from('characters')
          .delete()
          .eq('user_id', userId)
          .eq('name', name)
          .eq('is_template', true);

      _log.info('Successfully deleted template: $name');
    } catch (e, stack) {
      _log.severe('Error deleting template', e, stack);
      rethrow;
    }
  }

  // Update template publicity
  Future<void> updateTemplatePublicity(String name, bool isPublic,
      {String category = 'Custom'}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update publicity in the unified characters table
      await _supabase
          .from('characters')
          .update({
            'is_public': isPublic,
            'category': category,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('name', name)
          .eq('is_template', true);

      _log.info(
          'Successfully updated template publicity: $name, isPublic: $isPublic');
    } catch (e, stack) {
      _log.severe('Error updating template publicity', e, stack);
      rethrow;
    }
  }

  // Helper method to convert database record to AiCharacter
  AiCharacter _convertToAiCharacter(Map<String, dynamic> json) {
    try {
      // Handle example_messages conversion
      List<String> exampleMessages = [];
      if (json['example_messages'] != null) {
        if (json['example_messages'] is List) {
          exampleMessages = (json['example_messages'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }

      // Handle tags conversion
      List<String> tags = [];
      if (json['tags'] != null) {
        if (json['tags'] is List) {
          tags = (json['tags'] as List).map((e) => e.toString()).toList();
        }
      }

      // Add category to tags if not already present
      if (json['category'] != null &&
          !tags.contains(json['category']) &&
          json['category'] != 'Custom') {
        tags.add(json['category']);
      }

      return AiCharacter(
        name: json['name'],
        summary: json['summary'],
        personality: json['personality'],
        scenario: json['scenario'],
        greetingMessage: json['greeting_message'],
        exampleMessages: exampleMessages,
        avatarImagePath: json['avatar_image_path'],
        characterVersion: json['character_version'],
        systemPrompt: json['system_prompt'],
        tags: tags,
        creator: json['creator'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
    } catch (e, stack) {
      _log.severe('Error converting to AiCharacter: $e', e, stack);
      throw Exception('Failed to convert database record to AiCharacter: $e');
    }
  }
}
