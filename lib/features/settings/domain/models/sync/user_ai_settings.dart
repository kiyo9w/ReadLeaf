import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'user_ai_settings.freezed.dart';
part 'user_ai_settings.g.dart';

@freezed
class UserAISettings with _$UserAISettings {
  const factory UserAISettings({
    @Default('') String characterName,
    @Default([]) List<String> customCharacters,
    @Default(true) bool enableAutoSummary,
    @Default(true) bool enableContextualInsights,
    @Default({}) Map<String, dynamic> modelSpecificSettings,
  }) = _UserAISettings;

  factory UserAISettings.fromJson(Map<String, dynamic> json) =>
      _$UserAISettingsFromJson(json);
}
