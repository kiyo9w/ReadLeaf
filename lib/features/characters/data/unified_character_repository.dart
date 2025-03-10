import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'dart:async';

class UnifiedCharacterRepository {
  final _log = Logger('UnifiedCharacterRepository');
  final SupabaseClient _supabase;

  // Singleton instance
  static UnifiedCharacterRepository? _instance;

  // Factory constructor
  factory UnifiedCharacterRepository() {
    _instance ??=
        UnifiedCharacterRepository._internal(Supabase.instance.client);
    return _instance!;
  }

  // Private constructor
  UnifiedCharacterRepository._internal(this._supabase);

  // Get all public characters
  Future<List<AiCharacter>> getAllPublicCharacters({
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
      dynamic query =
          _supabase.from('characters').select('*').eq('is_public', true);

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

      // Check likes for the current user
      List<String> likedCharacterIds = [];
      if (userId != null) {
        try {
          final likes = await _supabase
              .from('character_likes')
              .select('character_id')
              .eq('user_id', userId);

          likedCharacterIds = (likes as List)
              .map((like) => like['character_id'] as String)
              .toList();
        } catch (e) {
          _log.warning('Error fetching likes: $e');
        }
      }

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final isLiked =
            userId != null && likedCharacterIds.contains(json['id']);
        return _convertToAiCharacter(json, isLiked);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting public characters', e, stack);
      return [];
    }
  }

  // Get a specific character by ID
  Future<AiCharacter?> getCharacterById(String id) async {
    try {
      _log.info('Getting character by ID: $id');

      final response =
          await _supabase.from('characters').select('*').eq('id', id).single();

      final userId = _supabase.auth.currentUser?.id;

      // Check if this character is liked by the current user
      bool isLiked = false;
      if (userId != null) {
        try {
          final like = await _supabase
              .from('character_likes')
              .select('id')
              .eq('user_id', userId)
              .eq('character_id', id)
              .maybeSingle();

          isLiked = like != null;
        } catch (e) {
          _log.warning('Error checking like status: $e');
        }
      }

      return _convertToAiCharacter(response, isLiked);
    } catch (e, stack) {
      _log.severe('Error getting character by ID', e, stack);
      return null;
    }
  }

  // Get characters by category
  Future<List<AiCharacter>> getCharactersByCategory(
    String category, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      _log.info('Getting characters by category: $category');

      final response = await _supabase
          .from('characters')
          .select('*')
          .eq('is_public', true)
          .eq('category', category)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final userId = _supabase.auth.currentUser?.id;

      // Check likes for the current user
      List<String> likedCharacterIds = [];
      if (userId != null) {
        try {
          final likes = await _supabase
              .from('character_likes')
              .select('character_id')
              .eq('user_id', userId);

          likedCharacterIds = (likes as List)
              .map((like) => like['character_id'] as String)
              .toList();
        } catch (e) {
          _log.warning('Error fetching likes: $e');
        }
      }

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final isLiked =
            userId != null && likedCharacterIds.contains(json['id']);
        return _convertToAiCharacter(json, isLiked);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting characters by category', e, stack);
      return [];
    }
  }

  // Get trending characters
  Future<List<AiCharacter>> getTrendingCharacters({int limit = 10}) async {
    try {
      _log.info('Getting trending characters');

      final response = await _supabase
          .from('characters')
          .select('*')
          .eq('is_public', true)
          .order('download_count', ascending: false)
          .limit(limit);

      final userId = _supabase.auth.currentUser?.id;

      // Check likes for the current user
      List<String> likedCharacterIds = [];
      if (userId != null) {
        try {
          final likes = await _supabase
              .from('character_likes')
              .select('character_id')
              .eq('user_id', userId);

          likedCharacterIds = (likes as List)
              .map((like) => like['character_id'] as String)
              .toList();
        } catch (e) {
          _log.warning('Error fetching likes: $e');
        }
      }

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final isLiked =
            userId != null && likedCharacterIds.contains(json['id']);
        return _convertToAiCharacter(json, isLiked);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting trending characters', e, stack);
      return [];
    }
  }

  // Get user's characters
  Future<List<AiCharacter>> getUserCharacters() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Getting characters for user: $userId');

      final response = await _supabase
          .from('characters')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        // User's own characters are considered "liked"
        return _convertToAiCharacter(json, true);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting user characters', e, stack);
      return [];
    }
  }

  // Get template characters
  Future<List<AiCharacter>> getTemplateCharacters() async {
    try {
      _log.info('Getting template characters');

      final response = await _supabase
          .from('characters')
          .select('*')
          .eq('is_template', true)
          .order('created_at', ascending: false);

      final userId = _supabase.auth.currentUser?.id;

      // Check likes for the current user
      List<String> likedCharacterIds = [];
      if (userId != null) {
        try {
          final likes = await _supabase
              .from('character_likes')
              .select('character_id')
              .eq('user_id', userId);

          likedCharacterIds = (likes as List)
              .map((like) => like['character_id'] as String)
              .toList();
        } catch (e) {
          _log.warning('Error fetching likes: $e');
        }
      }

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final isLiked =
            userId != null && likedCharacterIds.contains(json['id']);
        return _convertToAiCharacter(json, isLiked);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error getting template characters', e, stack);
      return [];
    }
  }

  // Save or update a character
  Future<AiCharacter?> saveCharacter(
    AiCharacter character, {
    bool isPublic = false,
    bool isTemplate = false,
    String category = 'Custom',
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Saving character: ${character.name}');

      final now = DateTime.now();

      // Convert task prompts to JSONB
      final taskPrompts = {
        'greeting': character.greetingMessage,
        'summary': character.summary,
        'scenario': character.scenario,
      };

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
        'is_public': isPublic,
        'is_template': isTemplate,
        'category': category,
        'task_prompts': taskPrompts,
        'created_at': character.createdAt.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response =
          await _supabase.from('characters').upsert(payload).select().single();

      return _convertToAiCharacter(response, false);
    } catch (e, stack) {
      _log.severe('Error saving character', e, stack);
      return null;
    }
  }

  // Delete a character
  Future<bool> deleteCharacter(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      _log.info('Deleting character: $id');

      await _supabase
          .from('characters')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      return true;
    } catch (e, stack) {
      _log.severe('Error deleting character', e, stack);
      return false;
    }
  }

  // Like a character
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

  // Unlike a character
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

  // Increment download count
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

  // Search characters
  Future<List<AiCharacter>> searchCharacters(
    String query, {
    int limit = 20,
    String? category,
  }) async {
    try {
      _log.info('Searching characters: $query');

      dynamic dbQuery = _supabase
          .from('characters')
          .select('*')
          .eq('is_public', true)
          .or('name.ilike.%$query%,summary.ilike.%$query%,tags.cs.{$query}');

      if (category != null && category.isNotEmpty && category != 'All') {
        dbQuery = dbQuery.eq('category', category);
      }

      final response =
          await dbQuery.order('created_at', ascending: false).limit(limit);

      final userId = _supabase.auth.currentUser?.id;

      // Check likes for the current user
      List<String> likedCharacterIds = [];
      if (userId != null) {
        try {
          final likes = await _supabase
              .from('character_likes')
              .select('character_id')
              .eq('user_id', userId);

          likedCharacterIds = (likes as List)
              .map((like) => like['character_id'] as String)
              .toList();
        } catch (e) {
          _log.warning('Error fetching likes: $e');
        }
      }

      return (response as List).map((json) {
        // Check if the character is liked by the current user
        final isLiked =
            userId != null && likedCharacterIds.contains(json['id']);
        return _convertToAiCharacter(json, isLiked);
      }).toList();
    } catch (e, stack) {
      _log.severe('Error searching characters', e, stack);
      return [];
    }
  }

  // Helper method to convert database record to AiCharacter
  AiCharacter _convertToAiCharacter(Map<String, dynamic> json, bool isLiked) {
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

      // Add isLiked to tags if applicable
      if (isLiked && !tags.contains('Liked')) {
        tags.add('Liked');
      }

      // Add category to tags if not already present
      if (json['category'] != null &&
          !tags.contains(json['category']) &&
          json['category'] != 'Custom') {
        tags.add(json['category']);
      }

      // Add template/public status to tags if applicable
      if (json['is_template'] == true && !tags.contains('Template')) {
        tags.add('Template');
      }

      if (json['is_public'] == true && !tags.contains('Public')) {
        tags.add('Public');
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
