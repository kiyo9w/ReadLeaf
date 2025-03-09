import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/features/characters/domain/models/public_character.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class PublicCharacterRepository {
  final _log = Logger('PublicCharacterRepository');
  final SupabaseClient _supabase;

  // Singleton instance
  static PublicCharacterRepository? _instance;

  // Factory constructor
  factory PublicCharacterRepository() {
    _instance ??= PublicCharacterRepository._internal(Supabase.instance.client);
    return _instance!;
  }

  // Private constructor
  PublicCharacterRepository._internal(this._supabase);

  // Get all public characters
  Future<List<PublicCharacter>> getAllPublicCharacters({
    int limit = 50,
    int offset = 0,
    String sortBy = 'created_at',
    bool descending = true,
    String? category,
    List<String>? tags,
  }) async {
    try {
      _log.info('Getting all public characters');

      // Start with base query
      dynamic query = _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('is_public', true);

      // Add category filter if specified
      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.eq('category', category);
      }

      // Add tags filter if specified
      if (tags != null && tags.isNotEmpty) {
        query = query.contains('tags', tags);
      }

      // Add sorting and pagination
      query = query
          .order(sortBy, ascending: !descending)
          .range(offset, offset + limit - 1);

      final response = await query;
      final userId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final characterLikes = json['character_likes'] as List?;
        final isLiked = userId != null &&
            (characterLikes != null
                ? characterLikes.any((like) => like['user_id'] == userId)
                : false);

        // Add isLiked field to the JSON
        json['is_liked'] = isLiked;

        return PublicCharacter.fromJson(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting public characters', e, stack);
      return [];
    }
  }

  // Get public characters by category
  Future<List<PublicCharacter>> getPublicCharactersByCategory(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      _log.info('Getting public characters by category: $category');

      final response = await _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('is_public', true)
          .eq('category', category)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final userId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final characterLikes = json['character_likes'] as List?;
        final isLiked = userId != null &&
            (characterLikes != null
                ? characterLikes.any((like) => like['user_id'] == userId)
                : false);

        // Add isLiked field to the JSON
        json['is_liked'] = isLiked;

        return PublicCharacter.fromJson(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting public characters by category', e, stack);
      return [];
    }
  }

  // Get trending public characters (most downloaded/liked)
  Future<List<PublicCharacter>> getTrendingPublicCharacters({
    int limit = 10,
  }) async {
    try {
      _log.info('Getting trending public characters');

      final response = await _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('is_public', true)
          .order('download_count', ascending: false)
          .limit(limit);

      final userId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final characterLikes = json['character_likes'] as List?;
        final isLiked = userId != null &&
            (characterLikes != null
                ? characterLikes.any((like) => like['user_id'] == userId)
                : false);

        // Add isLiked field to the JSON
        json['is_liked'] = isLiked;

        return PublicCharacter.fromJson(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting trending public characters', e, stack);
      return [];
    }
  }

  // Get public characters created by the current user
  Future<List<PublicCharacter>> getUserPublicCharacters() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Getting public characters for user: $userId');

      final response = await _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        // Check if the character is liked by the current user (always true for own characters)
        json['is_liked'] = true;

        return PublicCharacter.fromJson(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting user public characters', e, stack);
      return [];
    }
  }

  // Get a specific public character by ID
  Future<PublicCharacter?> getPublicCharacterById(String id) async {
    try {
      _log.info('Getting public character by ID: $id');

      final response = await _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('id', id)
          .single();

      final userId = _supabase.auth.currentUser?.id;

      // Check if the character is liked by the current user
      final characterLikes = response['character_likes'] as List?;
      final isLiked = userId != null &&
          (characterLikes != null
              ? characterLikes.any((like) => like['user_id'] == userId)
              : false);

      // Add isLiked field to the JSON
      response['is_liked'] = isLiked;

      return PublicCharacter.fromJson(response);
    } catch (e, stack) {
      _log.severe('Error getting public character by ID', e, stack);
      return null;
    }
  }

  // Publish a character to the public repository
  Future<PublicCharacter?> publishCharacter(
    AiCharacter character, {
    required String category,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Publishing character: ${character.name}');

      final payload = {
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
        'created_at': character.createdAt.toIso8601String(),
        'updated_at': character.updatedAt.toIso8601String(),
        'is_public': true,
        'category': category,
        'download_count': 0,
        'like_count': 0,
      };

      final response = await _supabase
          .from('public_characters')
          .upsert(payload)
          .select()
          .single();

      return PublicCharacter.fromJson({...response, 'is_liked': true});
    } catch (e, stack) {
      _log.severe('Error publishing character', e, stack);
      return null;
    }
  }

  // Update a public character
  Future<PublicCharacter?> updatePublicCharacter(
    PublicCharacter character,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (character.userId != userId) {
        throw Exception('Cannot update a character you do not own');
      }

      _log.info('Updating public character: ${character.name}');

      final payload = {
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
        'is_public': character.isPublic,
        'category': character.category,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('public_characters')
          .update(payload)
          .eq('id', character.id)
          .select()
          .single();

      return PublicCharacter.fromJson(
          {...response, 'is_liked': character.isLiked});
    } catch (e, stack) {
      _log.severe('Error updating public character', e, stack);
      return null;
    }
  }

  // Delete a public character
  Future<bool> deletePublicCharacter(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Deleting public character: $id');

      await _supabase
          .from('public_characters')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      return true;
    } catch (e, stack) {
      _log.severe('Error deleting public character', e, stack);
      return false;
    }
  }

  // Like a public character
  Future<bool> likeCharacter(String characterId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Liking character: $characterId');

      await _supabase.from('character_likes').upsert({
        'user_id': userId,
        'character_id': characterId,
      });

      return true;
    } catch (e, stack) {
      _log.severe('Error liking character', e, stack);
      return false;
    }
  }

  // Unlike a public character
  Future<bool> unlikeCharacter(String characterId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Unliking character: $characterId');

      await _supabase
          .from('character_likes')
          .delete()
          .eq('user_id', userId)
          .eq('character_id', characterId);

      return true;
    } catch (e, stack) {
      _log.severe('Error unliking character', e, stack);
      return false;
    }
  }

  // Increment download count for a character
  Future<bool> incrementDownloadCount(String characterId) async {
    try {
      _log.info('Incrementing download count for character: $characterId');

      await _supabase.rpc('increment_character_download_count', params: {
        'character_id': characterId,
      });

      return true;
    } catch (e, stack) {
      _log.severe('Error incrementing download count', e, stack);
      return false;
    }
  }

  // Search public characters
  Future<List<PublicCharacter>> searchPublicCharacters(
    String query, {
    int limit = 20,
    String? category,
  }) async {
    try {
      _log.info('Searching public characters: $query');

      dynamic dbQuery = _supabase
          .from('public_characters')
          .select('*, character_likes(user_id)')
          .eq('is_public', true)
          .or('name.ilike.%$query%,summary.ilike.%$query%,tags.cs.{$query}');

      if (category != null && category.isNotEmpty && category != 'All') {
        dbQuery = dbQuery.eq('category', category);
      }

      final response =
          await dbQuery.order('created_at', ascending: false).limit(limit);

      final userId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final characterLikes = json['character_likes'] as List?;
        final isLiked = userId != null &&
            (characterLikes != null
                ? characterLikes.any((like) => like['user_id'] == userId)
                : false);

        // Add isLiked field to the JSON
        json['is_liked'] = isLiked;

        return PublicCharacter.fromJson(json);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error searching public characters', e, stack);
      return [];
    }
  }
}
