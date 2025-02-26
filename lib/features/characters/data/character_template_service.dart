import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

class CharacterTemplateService {
  final _log = Logger('CharacterTemplateService');
  final _supabase = Supabase.instance.client;
  static const _templateDir = 'character_templates';

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
            // For now, use default avatar for http URLs
            return character.copyWith(
                avatarImagePath:
                    'assets/images/ai_characters/default_avatar.png');
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
      {bool isPublic = false}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('character_templates').upsert({
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
        'updated_at': DateTime.now().toIso8601String(),
      });
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

      final response = await _supabase
          .from('character_templates')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((json) => AiCharacter.fromJson(json))
          .toList();
    } catch (e, stack) {
      _log.severe('Error getting user templates', e, stack);
      rethrow;
    }
  }

  // Get public templates
  Future<List<AiCharacter>> getPublicTemplates() async {
    try {
      final response = await _supabase
          .from('character_templates')
          .select()
          .eq('is_public', true);

      return (response as List)
          .map((json) => AiCharacter.fromJson(json))
          .toList();
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

      await _supabase
          .from('character_templates')
          .delete()
          .eq('user_id', userId)
          .eq('name', name);
    } catch (e, stack) {
      _log.severe('Error deleting template', e, stack);
      rethrow;
    }
  }

  // Update template publicity
  Future<void> updateTemplatePublicity(String name, bool isPublic) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('character_templates')
          .update({'is_public': isPublic})
          .eq('user_id', userId)
          .eq('name', name);
    } catch (e, stack) {
      _log.severe('Error updating template publicity', e, stack);
      rethrow;
    }
  }
}
