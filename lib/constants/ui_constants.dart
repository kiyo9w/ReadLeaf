import 'package:flutter/material.dart';

class UIConstants {
  // Colors
  static const Color primaryBackgroundColor = Colors.white;
  static const Color secondaryBackgroundColor = Color(0xffDDDDDD);
  static const Color primaryTextColor = Colors.black;
  static const Color secondaryTextColor = Colors.black54;

  // Dimensions
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 50.0;

  // Text Styles
  static const TextStyle titleStyle = TextStyle(
    fontSize: 42.0,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
  );

  // Animation Durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Dimensions for specific widgets
  static const double characterSpacing = 100.0;
  static const double characterAvatarSize = 120.0;
  static const double minimalCardWidth = 120.0;
  static const double searchBarHeight = 50.0;
}
