import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:read_leaf/models/ai_character.dart';
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
      final file = File(jsonPath);
      if (!await file.exists()) {
        throw Exception('Template file not found');
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString);
      final character = AiCharacter.fromJson(json);

      // Validate the template
      final validationError = AiCharacter.validate(
        name: character.name,
        summary: character.summary,
        personality: character.personality,
        scenario: character.scenario,
        greetingMessage: character.greetingMessage,
        exampleMessages: character.exampleMessages,
        avatarImagePath: character.avatarImagePath,
      );

      if (validationError != null) {
        throw Exception('Invalid template: $validationError');
      }

      // Copy avatar image to local storage if it's not already there
      if (!character.avatarImagePath.startsWith('assets/')) {
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
        }
      }

      return character;
    } catch (e, stack) {
      _log.severe('Error importing template', e, stack);
      rethrow;
    }
  }

  // Export a character template to JSON file
  Future<String> exportTemplate(AiCharacter character) async {
    try {
      final templateDir = await _localTemplateDir;
      final fileName =
          '${character.name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path.join(templateDir.path, fileName));

      final json = character.toJson();
      await file.writeAsString(jsonEncode(json));

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
