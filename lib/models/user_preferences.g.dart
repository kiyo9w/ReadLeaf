// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserPreferencesImpl _$$UserPreferencesImplFromJson(
        Map<String, dynamic> json) =>
    _$UserPreferencesImpl(
      darkMode: json['darkMode'] as bool? ?? false,
      fontSize: json['fontSize'] as String? ?? 'medium',
      enableAIFeatures: json['enableAIFeatures'] as bool? ?? true,
      showReadingProgress: json['showReadingProgress'] as bool? ?? true,
      enableAutoSync: json['enableAutoSync'] as bool? ?? false,
      customSettings:
          (json['customSettings'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$$UserPreferencesImplToJson(
        _$UserPreferencesImpl instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'fontSize': instance.fontSize,
      'enableAIFeatures': instance.enableAIFeatures,
      'showReadingProgress': instance.showReadingProgress,
      'enableAutoSync': instance.enableAutoSync,
      'customSettings': instance.customSettings,
    };
