// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicCharacter _$PublicCharacterFromJson(Map<String, dynamic> json) =>
    PublicCharacter(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      summary: json['summary'] as String,
      personality: json['personality'] as String,
      scenario: json['scenario'] as String,
      greetingMessage: json['greeting_message'] as String,
      exampleMessages: (json['example_messages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      avatarImagePath: json['avatar_image_path'] as String,
      characterVersion: json['character_version'] as String,
      systemPrompt: json['system_prompt'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      creator: json['creator'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPublic: json['is_public'] as bool,
      downloadCount: (json['download_count'] as num).toInt(),
      likeCount: (json['like_count'] as num).toInt(),
      category: json['category'] as String,
      isLiked: json['is_liked'] as bool? ?? false,
    );

Map<String, dynamic> _$PublicCharacterToJson(PublicCharacter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'name': instance.name,
      'summary': instance.summary,
      'personality': instance.personality,
      'scenario': instance.scenario,
      'greeting_message': instance.greetingMessage,
      'example_messages': instance.exampleMessages,
      'avatar_image_path': instance.avatarImagePath,
      'character_version': instance.characterVersion,
      'system_prompt': instance.systemPrompt,
      'tags': instance.tags,
      'creator': instance.creator,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'is_public': instance.isPublic,
      'download_count': instance.downloadCount,
      'like_count': instance.likeCount,
      'category': instance.category,
      'is_liked': instance.isLiked,
    };
