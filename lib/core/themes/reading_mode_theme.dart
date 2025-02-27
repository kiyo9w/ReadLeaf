import 'package:flutter/material.dart';

class ReadingModeTheme {
  static const Color consoleBackground = Colors.black;
  static const Color consoleText = Colors.white;

  static const Color nightContrastBackground = Color(0xFF121212);
  static const Color nightContrastText = Colors.white;

  static const Color nightModeBackground = Color(0xFF1F1F1F);
  static const Color nightModeText = Color(0xFFCCCCCC);
  static const Color nightModeHeaderText = Colors.white;

  static const Color twilightBackground = Color(0xFF2F3136);
  static const Color twilightText = Colors.white;

  static const Color birthdayBackground = Color(0xFF673AB7);
  static const Color birthdayText = Colors.white;

  static Color getBackgroundColor(ReadingMode mode) {
    switch (mode) {
      case ReadingMode.console:
        return consoleBackground;
      case ReadingMode.darkContrast:
        return nightContrastBackground;
      case ReadingMode.dark:
        return nightModeBackground;
      case ReadingMode.twilight:
        return twilightBackground;
      case ReadingMode.birthday:
        return birthdayBackground;
      case ReadingMode.sepia:
        return const Color(0xFFF4ECD8);
      default:
        return Colors.white;
    }
  }

  static Color getTextColor(ReadingMode mode, {bool isHeader = false}) {
    switch (mode) {
      case ReadingMode.console:
        return const Color.fromARGB(255, 1, 14, 7);
      case ReadingMode.darkContrast:
        return nightContrastText;
      case ReadingMode.dark:
        return isHeader ? nightModeHeaderText : nightModeText;
      case ReadingMode.twilight:
        return twilightText;
      case ReadingMode.birthday:
        return birthdayText;
      case ReadingMode.sepia:
        return Colors.brown.shade900;
      default:
        return Colors.black;
    }
  }
}

enum ReadingMode {
  light,
  dark,
  darkContrast,
  sepia,
  twilight,
  console,
  birthday
}
