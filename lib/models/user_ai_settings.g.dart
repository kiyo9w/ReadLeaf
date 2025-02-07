// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_ai_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserAISettingsImpl _$$UserAISettingsImplFromJson(Map<String, dynamic> json) =>
    _$UserAISettingsImpl(
      characterName: json['characterName'] as String? ?? '',
      customCharacters: (json['customCharacters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      enableAutoSummary: json['enableAutoSummary'] as bool? ?? true,
      enableContextualInsights:
          json['enableContextualInsights'] as bool? ?? true,
      modelSpecificSettings:
          json['modelSpecificSettings'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$UserAISettingsImplToJson(
        _$UserAISettingsImpl instance) =>
    <String, dynamic>{
      'characterName': instance.characterName,
      'customCharacters': instance.customCharacters,
      'enableAutoSummary': instance.enableAutoSummary,
      'enableContextualInsights': instance.enableContextualInsights,
      'modelSpecificSettings': instance.modelSpecificSettings,
    };
