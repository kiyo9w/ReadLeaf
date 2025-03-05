import 'package:json_annotation/json_annotation.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';

part 'public_character.g.dart';

@JsonSerializable()
class PublicCharacter {
  final String id;
  final String userId;
  final String name;
  final String summary;
  final String personality;
  final String scenario;
  @JsonKey(name: 'greeting_message')
  final String greetingMessage;
  @JsonKey(name: 'example_messages', defaultValue: [])
  final List<String> exampleMessages;
  @JsonKey(name: 'avatar_image_path')
  final String avatarImagePath;
  @JsonKey(name: 'character_version')
  final String characterVersion;
  @JsonKey(name: 'system_prompt')
  final String? systemPrompt;
  @JsonKey(defaultValue: [])
  final List<String> tags;
  final String creator;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'is_public')
  final bool isPublic;
  @JsonKey(name: 'download_count')
  final int downloadCount;
  @JsonKey(name: 'like_count')
  final int likeCount;
  final String category;
  @JsonKey(name: 'is_liked', defaultValue: false)
  final bool isLiked;

  const PublicCharacter({
    required this.id,
    required this.userId,
    required this.name,
    required this.summary,
    required this.personality,
    required this.scenario,
    required this.greetingMessage,
    required this.exampleMessages,
    required this.avatarImagePath,
    required this.characterVersion,
    this.systemPrompt,
    required this.tags,
    required this.creator,
    required this.createdAt,
    required this.updatedAt,
    required this.isPublic,
    required this.downloadCount,
    required this.likeCount,
    required this.category,
    required this.isLiked,
  });

  // Factory constructor to create a PublicCharacter from JSON
  factory PublicCharacter.fromJson(Map<String, dynamic> json) =>
      _$PublicCharacterFromJson(json);

  // Convert a PublicCharacter instance to JSON
  Map<String, dynamic> toJson() => _$PublicCharacterToJson(this);

  // Convert to AiCharacter
  AiCharacter toAiCharacter() {
    return AiCharacter(
      name: name,
      summary: summary,
      personality: personality,
      scenario: scenario,
      greetingMessage: greetingMessage,
      exampleMessages: exampleMessages,
      avatarImagePath: avatarImagePath,
      characterVersion: characterVersion,
      systemPrompt: systemPrompt,
      tags: [...tags, category],
      creator: creator,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create a copy of the character with optional field updates
  PublicCharacter copyWith({
    String? id,
    String? userId,
    String? name,
    String? summary,
    String? personality,
    String? scenario,
    String? greetingMessage,
    List<String>? exampleMessages,
    String? avatarImagePath,
    String? characterVersion,
    String? systemPrompt,
    List<String>? tags,
    String? creator,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    int? downloadCount,
    int? likeCount,
    String? category,
    bool? isLiked,
  }) {
    return PublicCharacter(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      greetingMessage: greetingMessage ?? this.greetingMessage,
      exampleMessages: exampleMessages ?? this.exampleMessages,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      characterVersion: characterVersion ?? this.characterVersion,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      tags: tags ?? this.tags,
      creator: creator ?? this.creator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      downloadCount: downloadCount ?? this.downloadCount,
      likeCount: likeCount ?? this.likeCount,
      category: category ?? this.category,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
