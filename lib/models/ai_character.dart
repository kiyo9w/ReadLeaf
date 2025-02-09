import 'package:json_annotation/json_annotation.dart';

part 'ai_character.g.dart';

@JsonSerializable()
class AiCharacter {
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

  const AiCharacter({
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
  });

  // Factory constructor to create an AiCharacter from JSON
  factory AiCharacter.fromJson(Map<String, dynamic> json) =>
      _$AiCharacterFromJson(json);

  // Convert an AiCharacter instance to JSON
  Map<String, dynamic> toJson() => _$AiCharacterToJson(this);

  // Create a copy of the character with optional field updates
  AiCharacter copyWith({
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
  }) {
    return AiCharacter(
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
    );
  }

  // Validation method
  static String? validate({
    String? name,
    String? summary,
    String? personality,
    String? scenario,
    String? greetingMessage,
    List<String>? exampleMessages,
    String? avatarImagePath,
  }) {
    if (name?.isEmpty ?? true) return 'Name is required';
    if (summary?.isEmpty ?? true) return 'Summary is required';
    if ((summary?.length ?? 0) > 200)
      return 'Summary must be less than 200 characters';
    if (personality?.isEmpty ?? true) return 'Personality is required';
    if ((personality?.length ?? 0) > 1000)
      return 'Personality must be less than 1000 characters';
    if (scenario?.isEmpty ?? true) return 'Scenario is required';
    if ((scenario?.length ?? 0) > 1000)
      return 'Scenario must be less than 1000 characters';
    if (greetingMessage?.isEmpty ?? true) return 'Greeting message is required';
    if ((greetingMessage?.length ?? 0) > 500)
      return 'Greeting message must be less than 500 characters';
    if ((exampleMessages?.length ?? 0) > 10)
      return 'Maximum 10 example messages allowed';
    if (exampleMessages?.any((msg) => msg.length > 200) ?? false) {
      return 'Example messages must be less than 200 characters each';
    }
    if (avatarImagePath?.isEmpty ?? true)
      return 'Avatar image path is required';

    return null;
  }

  // Helper method to get the character's display trait (first tag or default)
  String get trait => tags.isNotEmpty ? tags.first : 'AI Character';

  // Helper method to generate a system prompt if none is provided
  String getEffectiveSystemPrompt() {
    if (systemPrompt != null && systemPrompt!.isNotEmpty) {
      return systemPrompt!;
    }

    return '''You are ${name}, ${personality}

SCENARIO:
$scenario

ROLEPLAY RULES:
- Chat exclusively as $name
- Keep responses personal and in-character
- Use subtle physical cues to hint at mental state
- Include internal thoughts in asterisks *like this*
- Keep responses concise (2-3 sentences)
- Stay in character at all times
- Express emotions and reactions naturally
- Use your character's unique way of speaking''';
  }
}
