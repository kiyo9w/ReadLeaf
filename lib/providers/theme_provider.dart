import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/themes/custom_theme_extension.dart';
import 'package:read_leaf/services/user_preferences_service.dart';
import 'package:read_leaf/models/user_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeBoxName = 'theme_box';
  static const String _isDarkModeKey = 'is_dark_mode';
  final UserPreferencesService _preferencesService;
  late ThemeData _theme;
  bool _isDarkMode;

  ThemeProvider(this._preferencesService) : _isDarkMode = false {
    _loadPreferences();
  }

  ThemeData get theme => _theme;
  bool get isDarkMode => _isDarkMode;

  void _loadPreferences() {
    final preferences = _preferencesService.getPreferences();
    _isDarkMode = preferences.darkMode;
    _updateTheme();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _updateTheme();
    _savePreferences();
  }

  void _updateTheme() {
    if (_isDarkMode) {
      _theme = _darkTheme;
    } else {
      _theme = _lightTheme;
    }
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final currentPrefs = _preferencesService.getPreferences();
    final updatedPrefs = currentPrefs.copyWith(darkMode: _isDarkMode);
    await _preferencesService.savePreferences(updatedPrefs);
  }

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,

    // Add page transitions theme
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.black87, fontSize: 14),
      titleLarge: TextStyle(
          color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.black87, fontSize: 16),
      labelLarge: TextStyle(color: Colors.black87, fontSize: 14),
    ),

    // Icon theme
    iconTheme: const IconThemeData(
      color: Colors.black87,
      size: 24,
    ),

    // Navigation bar theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colors.blue.withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Colors.black12,
      thickness: 1,
      space: 1,
    ),

    // Custom color extensions for file cards and AI messages
    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Colors.white,
        fileCardText: Colors.black87,
        aiMessageBackground: Colors.white,
        aiMessageText: Colors.black87,
        minimalFileCardBackground: Colors.white,
        minimalFileCardText: Colors.black87,
      ),
    ],
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: Color(0xFF9C27B0), // Mystic purple for AI character
    scaffoldBackgroundColor: Color(0xFF121212), // Deep dark background

    // Add page transitions theme
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A), // Slightly lighter than scaffold
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent, // Important for SliverAppBar
      scrolledUnderElevation: 0, // No elevation when scrolled under
    ),

    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
      titleLarge: TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      bodySmall: TextStyle(color: Colors.white70, fontSize: 12),
      labelSmall: TextStyle(color: Colors.white70, fontSize: 11),
    ),

    // Icon theme
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24,
    ),

    // Navigation bar theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      indicatorColor:
          Color(0xFF9C27B0).withOpacity(0.2), // Mystic purple indicator
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      color: const Color(0xFF2A2A2A), // Lighter grey for cards
      elevation: 8,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A), // Matching the card color
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFF9C27B0), width: 2), // Mystic purple border
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.white54),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Colors.white24,
      thickness: 1,
      space: 1,
    ),

    // Custom color extensions for file cards and AI messages
    extensions: [
      const CustomThemeExtension(
        fileCardBackground:
            Color.fromARGB(255, 26, 28, 40), // Lighter grey for better contrast
        fileCardText: Colors.white,
        aiMessageBackground: Color.fromARGB(
            255, 21, 3, 44), // Deep mystic purple for AI messages
        aiMessageText: Colors.white,
        minimalFileCardBackground:
            Color(0xFF2A2A2A), // Matching grey for minimal cards
        minimalFileCardText: Colors.white,
      ),
    ],
  );
}
