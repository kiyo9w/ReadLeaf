import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/themes/custom_theme_extension.dart';
import 'package:read_leaf/services/user_preferences_service.dart';
import 'package:read_leaf/models/user_preferences.dart';

enum AppThemeMode {
  classicLight,
  readLeafLight,
  mysteriousDark,
  classicDark,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeBoxName = 'theme_box';
  static const String _isDarkModeKey = 'is_dark_mode';
  final UserPreferencesService _preferencesService;
  late ThemeData _theme;
  AppThemeMode _currentThemeMode;

  ThemeProvider(this._preferencesService)
      : _currentThemeMode = AppThemeMode.classicLight {
    _loadPreferences();
  }

  ThemeData get theme => _theme;
  AppThemeMode get currentThemeMode => _currentThemeMode;
  String get currentThemeName {
    switch (_currentThemeMode) {
      case AppThemeMode.classicLight:
        return 'Classic Light';
      case AppThemeMode.readLeafLight:
        return 'Read Leaf Light';
      case AppThemeMode.mysteriousDark:
        return 'Mysterious Dark';
      case AppThemeMode.classicDark:
        return 'Classic Dark';
    }
  }

  void _loadPreferences() {
    final preferences = _preferencesService.getPreferences();
    // For now, maintain backwards compatibility with the old dark mode setting
    _currentThemeMode = preferences.darkMode
        ? AppThemeMode.classicDark
        : AppThemeMode.classicLight;
    _updateTheme();
  }

  void setThemeMode(AppThemeMode mode) {
    _currentThemeMode = mode;
    _updateTheme();
    _savePreferences();
  }

  void _updateTheme() {
    switch (_currentThemeMode) {
      case AppThemeMode.classicLight:
        _theme = _lightTheme;
        break;
      case AppThemeMode.readLeafLight:
        _theme = _lightTheme; // TODO: Implement custom Read Leaf light theme
        break;
      case AppThemeMode.mysteriousDark:
        _theme = _darkTheme;
        break;
      case AppThemeMode.classicDark:
        _theme = _darkTheme;
        break;
    }
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final currentPrefs = _preferencesService.getPreferences();
    // For now, maintain backwards compatibility by mapping to dark mode
    final isDark = _currentThemeMode == AppThemeMode.mysteriousDark ||
        _currentThemeMode == AppThemeMode.classicDark;
    final updatedPrefs = currentPrefs.copyWith(darkMode: isDark);
    await _preferencesService.savePreferences(updatedPrefs);
  }

  /// --- Light Theme (Warm Minimalist "Japandi" style) ---
  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Core brand / accent colors
    primaryColor: const Color(0xFF6B8F71), // Soft sage/olive green
    scaffoldBackgroundColor: const Color(0xFFF5F2ED), // Warm off-white
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    hintColor: const Color(0xFF8C9A76), // Subtle greenish hint
    highlightColor: const Color(0xFF4C6A43), // Darker green for highlights

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6B8F71), // Sage/Olive
      secondary: Color(0xFFB5A89E), // Warm neutral
      tertiary: Color(0xFFE9CFA3), // Light, warm golden
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF5F2ED),
      error: Color(0xFFBA1A1A),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFF1B1B1B),
      onSurface: Color(0xFF1B1B1B),
      onBackground: Color(0xFF1B1B1B),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFF6B8F71), // Tint surfaces with sage
      primaryContainer: Color(0xFFC4D9C7), // Lighter sage for containers
      secondaryContainer: Color(0xFFD9D2CB), // Lighter warm neutral
      tertiaryContainer: Color(0xFFF3E2CC), // Lighter golden accent
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F2ED), // Same as scaffold
      foregroundColor: Colors.black87,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Colors.black87, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.black87, fontSize: 14),
      titleLarge: TextStyle(
          color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
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
      backgroundColor: const Color(0xFFF5F2ED),
      indicatorColor: const Color(0xFF6B8F71).withOpacity(0.2),
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
      fillColor: Color(0xFFF5F2ED),
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
        borderSide:
            BorderSide(color: Color(0xFF6B8F71), width: 2), // Sage/Olive
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
      space: 1,
    ),

    // Floating Action Button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF6B8F71),
      foregroundColor: Colors.white,
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor:
          MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71); // Sage/Olive when selected
        }
        return Color(0xFFE0E0E0); // Light grey when unselected
      }),
    ),

    // Radio theme
    radioTheme: RadioThemeData(
      fillColor:
          MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71); // Sage/Olive when selected
        }
        return Color(0xFFE0E0E0); // Light grey when unselected
      }),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor:
          MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71); // Sage/Olive
        }
        return Colors.grey;
      }),
      trackColor:
          MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71).withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),

    // Progress indicator theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF6B8F71), // Sage/Olive
    ),

    // Chip theme
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF5F2ED),
      selectedColor: const Color(0xFF6B8F71).withOpacity(0.2),
      disabledColor: Colors.grey.withOpacity(0.3),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Colors.black87),
    ),

    // Custom color extensions for file cards and AI messages
    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Colors.white,
        fileCardText: Colors.black87,
        aiMessageBackground: Color(0xFFF5F2ED),
        aiMessageText: Colors.black87,
        minimalFileCardBackground: Colors.white,
        minimalFileCardText: Colors.black87,
      ),
    ],
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Core brand / accent colors
    primaryColor: const Color(0xFF6B8F71), // Same sage/olive from light theme
    scaffoldBackgroundColor: const Color(0xFF1B1B1B), // Deep charcoal
    cardColor: const Color(0xFF242424), // Slightly lighter dark grey
    dividerColor: const Color(0xFF303030),
    hintColor: const Color(0xFF8C8C8C), // Subtle grey for hints
    highlightColor: const Color(0xFF6B8F71), // Sage highlight

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6B8F71), // Sage/Olive accent
      secondary: Color(0xFFB5A89E), // Warm neutral from light theme
      tertiary: Color(0xFFE9CFA3), // Subtle golden from light theme
      surface: Color(0xFF242424),
      background: Color(0xFF1B1B1B),
      error: Color(0xFFCF6679),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFDADADA),
      onBackground: Color(0xFFDADADA),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFF6B8F71),
      primaryContainer: Color(0xFF3A4B3C), // Darker sage
      secondaryContainer: Color(0xFF4B453F), // Darker warm neutral
      tertiaryContainer: Color(0xFF4D4536), // Darker golden accent
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1B1B1B), // Matches scaffold for seamless look
      foregroundColor: Color(0xFFDADADA), // Light grey text/icons
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFDADADA)),
      titleTextStyle: TextStyle(
        color: Color(0xFFDADADA),
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),

    // Text themes
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Color(0xFFDADADA), // Heading text
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: Color(0xFFDADADA),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFC7C7C7),
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFC7C7C7),
        fontSize: 14,
      ),
      titleLarge: TextStyle(
        color: Color(0xFFDADADA),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: Color(0xFFDADADA),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        color: Color(0xFFC7C7C7),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: Color(0xFFA3A3A3),
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        color: Color(0xFFA3A3A3),
        fontSize: 11,
      ),
    ),

    // Icon theme
    iconTheme: const IconThemeData(
      color: Color(0xFFDADADA),
      size: 24,
    ),

    // Navigation bar theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1B1B1B), // Same as scaffold
      indicatorColor: const Color(0xFF6B8F71).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFDADADA),
        ),
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      color: const Color(0xFF242424),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF242424),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF242424),
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
        borderSide: BorderSide(
          color: Color(0xFF6B8F71), // Sage accent
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFFA3A3A3)),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Color(0xFF303030),
      thickness: 1,
      space: 1,
    ),

    // Floating Action Button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF6B8F71),
      foregroundColor: Color(0xFFFFFFFF),
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71);
        }
        return const Color(0xFF303030);
      }),
    ),

    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71);
        }
        return const Color(0xFF303030);
      }),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71);
        }
        return const Color(0xFF757575);
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF6B8F71).withOpacity(0.5);
        }
        return const Color(0xFF757575).withOpacity(0.3);
      }),
    ),

    // Progress indicator theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF6B8F71),
    ),

    // Chip theme
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF242424),
      selectedColor: const Color(0xFF6B8F71).withOpacity(0.2),
      disabledColor: const Color(0xFF757575),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Color(0xFFDADADA)),
    ),

    // Custom color extensions for file cards and AI messages
    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Color(0xFF242424),
        fileCardText: Color(0xFFDADADA),
        aiMessageBackground: Color(0xFF242424),
        aiMessageText: Color(0xFFC7C7C7),
        minimalFileCardBackground: Color(0xFF242424),
        minimalFileCardText: Color(0xFFDADADA),
      ),
    ],
  );
}
