// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiCharacter _$AiCharacterFromJson(Map<String, dynamic> json) => AiCharacter(
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
    );

Map<String, dynamic> _$AiCharacterToJson(AiCharacter instance) =>
    <String, dynamic>{
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
    };
