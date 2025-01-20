import 'package:flutter/material.dart';

@immutable
class CustomThemeExtension extends ThemeExtension<CustomThemeExtension> {
  final Color fileCardBackground;
  final Color fileCardText;
  final Color aiMessageBackground;
  final Color aiMessageText;
  final Color minimalFileCardBackground;
  final Color minimalFileCardText;

  const CustomThemeExtension({
    required this.fileCardBackground,
    required this.fileCardText,
    required this.aiMessageBackground,
    required this.aiMessageText,
    required this.minimalFileCardBackground,
    required this.minimalFileCardText,
  });

  @override
  CustomThemeExtension copyWith({
    Color? fileCardBackground,
    Color? fileCardText,
    Color? aiMessageBackground,
    Color? aiMessageText,
    Color? minimalFileCardBackground,
    Color? minimalFileCardText,
  }) {
    return CustomThemeExtension(
      fileCardBackground: fileCardBackground ?? this.fileCardBackground,
      fileCardText: fileCardText ?? this.fileCardText,
      aiMessageBackground: aiMessageBackground ?? this.aiMessageBackground,
      aiMessageText: aiMessageText ?? this.aiMessageText,
      minimalFileCardBackground:
          minimalFileCardBackground ?? this.minimalFileCardBackground,
      minimalFileCardText: minimalFileCardText ?? this.minimalFileCardText,
    );
  }

  @override
  CustomThemeExtension lerp(
      ThemeExtension<CustomThemeExtension>? other, double t) {
    if (other is! CustomThemeExtension) {
      return this;
    }
    return CustomThemeExtension(
      fileCardBackground:
          Color.lerp(fileCardBackground, other.fileCardBackground, t)!,
      fileCardText: Color.lerp(fileCardText, other.fileCardText, t)!,
      aiMessageBackground:
          Color.lerp(aiMessageBackground, other.aiMessageBackground, t)!,
      aiMessageText: Color.lerp(aiMessageText, other.aiMessageText, t)!,
      minimalFileCardBackground: Color.lerp(
          minimalFileCardBackground, other.minimalFileCardBackground, t)!,
      minimalFileCardText:
          Color.lerp(minimalFileCardText, other.minimalFileCardText, t)!,
    );
  }
}
