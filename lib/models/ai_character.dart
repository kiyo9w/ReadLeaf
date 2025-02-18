import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';

part 'ai_character.g.dart';

class AiGenerationParams {
  final double temperature;
  final int maxLength;
  final double topP;
  final int topK;
  final double repetitionPenalty;
  final int repetitionPenaltyRange;
  final double typicalP;
  final double tailFreeSampling;

  const AiGenerationParams({
    this.temperature = 0.69,
    this.maxLength = 2048,
    this.topP = 0.9,
    this.topK = 0,
    this.repetitionPenalty = 1.06,
    this.repetitionPenaltyRange = 2048,
    this.typicalP = 1,
    this.tailFreeSampling = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'maxLength': maxLength,
        'topP': topP,
        'topK': topK,
        'repetitionPenalty': repetitionPenalty,
        'repetitionPenaltyRange': repetitionPenaltyRange,
        'typicalP': typicalP,
        'tailFreeSampling': tailFreeSampling,
      };

  factory AiGenerationParams.fromJson(Map<String, dynamic> json) {
    return AiGenerationParams(
      temperature: json['temperature'] ?? 0.69,
      maxLength: json['maxLength'] ?? 2048,
      topP: json['topP'] ?? 0.9,
      topK: json['topK'] ?? 0,
      repetitionPenalty: json['repetitionPenalty'] ?? 1.06,
      repetitionPenaltyRange: json['repetitionPenaltyRange'] ?? 2048,
      typicalP: json['typicalP'] ?? 1,
      tailFreeSampling: json['tailFreeSampling'] ?? 1.0,
    );
  }
}

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
  final AiGenerationParams generationParams;

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
    this.generationParams = const AiGenerationParams(),
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
    AiGenerationParams? generationParams,
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
      generationParams: generationParams ?? this.generationParams,
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
    if (summary?.isEmpty ?? true) return 'Description/Summary is required';
    try {
      if (summary!.trim().startsWith('{')) {
        json.decode(summary);
      }
    } catch (e) {
      // return 'Summary must be a valid JSON string';
    }

    // Personality is optional
    if (personality != null && personality.length > 50000) {
      return 'Personality must be less than 50000 characters';
    }

    // Scenario is required
    if (scenario?.isEmpty ?? true) return 'Scenario is required';
    if (scenario!.length > 50000) {
      return 'Scenario must be less than 50000 characters';
    }

    // Greeting message is required (first_mes in template)
    if (greetingMessage?.isEmpty ?? true) return 'Greeting message is required';
    if (greetingMessage!.length > 50000) {
      return 'Greeting message must be less than 50000 characters';
    }

    // Example messages are optional but should be validated if present
    if (exampleMessages != null) {
      if (exampleMessages.length > 100) {
        return 'Maximum 100 example messages allowed';
      }
      if (exampleMessages.any((msg) => msg.length > 50000)) {
        return 'Example messages must be less than 50000 characters each';
      }
    }

    // Avatar can be a URL, local path, or asset path
    if (avatarImagePath?.isEmpty ?? true) {
      return 'Avatar image path is required';
    }

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
