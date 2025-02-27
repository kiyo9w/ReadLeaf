import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default(false) bool darkMode,
    @Default('medium') String fontSize,
    @Default(true) bool enableAIFeatures,
    @Default(true) bool showReadingProgress,
    @Default(false) bool enableAutoSync,
    @Default({}) Map<String, dynamic> customSettings,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}
