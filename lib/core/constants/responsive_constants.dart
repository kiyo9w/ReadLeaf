import 'package:flutter/material.dart';

class ResponsiveConstants {
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  static bool isLargeTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 900;
  }

  // Bottom bar heights
  static double getBottomBarHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    if (isLargeTablet(context)) return 50.0 + bottomPadding;
    if (isTablet(context)) return 40.0 + bottomPadding;
    return 24.0 + bottomPadding;
  }

  // Side navigation width
  static double getSideNavWidth(BuildContext context) {
    if (isLargeTablet(context)) return 450.0; // Fixed width for large tablets
    if (isTablet(context)) return 400.0; // Fixed width for tablets
    return 335.0;
  }

  // Floating chat head size
  static double getFloatingChatHeadSize(BuildContext context) {
    if (isLargeTablet(context)) return 96.0; // Large tablets
    if (isTablet(context)) return 80.0; // Tablets
    return 65.0; // Mobile devices
  }

  static double getSafeAreaBottom(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double getBookInfoMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isLargeTablet(context)) return width * 0.75;
    if (isTablet(context)) return width * 0.8;
    return width - 32;
  }

  static double getBookInfoMaxHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return height * 0.75;
  }

  // Content padding
  static EdgeInsets getContentPadding(BuildContext context) {
    if (isLargeTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0);
    }
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
  }

  // Font sizes
  static double getTitleFontSize(BuildContext context) {
    if (isLargeTablet(context)) return 32.0;
    if (isTablet(context)) return 28.0;
    return 24.0;
  }

  static double getBodyFontSize(BuildContext context) {
    if (isTablet(context)) return 16.0;
    return 14.0;
  }

  // Icon sizes
  static double getIconSize(BuildContext context) {
    if (isTablet(context)) return 24.0;
    return 20.0;
  }

  // Button heights
  static double getButtonHeight(BuildContext context) {
    if (isTablet(context)) return 56.0;
    return 48.0;
  }

  // Grid layout
  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    return 3;
  }

  // Chat dimensions
  static double getMinChatWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isLargeTablet(context)) return width * 0.3;
    if (isTablet(context)) return width * 0.35;
    return 280.0;
  }

  static double getMaxChatWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isLargeTablet(context)) return width * 0.8;
    if (isTablet(context)) return width * 0.8;
    return width - 32;
  }

  // Bottom sheet dimensions
  static double getBottomSheetMinHeight(BuildContext context) {
    if (isTablet(context)) return 0.4;
    return 0.3;
  }

  static double getBottomSheetMaxHeight(BuildContext context) {
    if (isTablet(context)) return 0.9;
    return 0.8;
  }
}
