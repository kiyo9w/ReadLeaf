import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/themes/custom_theme_extension.dart';
import 'package:read_leaf/services/user_preferences_service.dart';
import 'package:read_leaf/models/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  readLeafLight, // Light
  classicLight, // Luminous
  oceanBlue, // Ocean
  mysteriousDark, // Dark
  classicDark, // Archaic
  darkForest, // Forest
  pinkCutesy, // Candy
  midNight, // Midnight
}

class ThemeProvider extends ChangeNotifier {
  static const String _themeBoxName = 'theme_box';
  static const String _isDarkModeKey = 'is_dark_mode';
  final UserPreferencesService _preferencesService;
  late ThemeData _theme;
  AppThemeMode _currentThemeMode;
  AppThemeMode? _lastLightTheme;
  AppThemeMode? _lastDarkTheme;

  // Add system theme support
  bool _useSystemTheme = false;
  bool get useSystemTheme => _useSystemTheme;

  bool _showReadingReminders = true;
  bool get showReadingReminders => _showReadingReminders;

  ThemeProvider(this._preferencesService)
      : _currentThemeMode = AppThemeMode.classicLight {
    _loadPreferences();
  }

  ThemeData get theme => _theme;
  AppThemeMode get currentThemeMode => _currentThemeMode;
  String get currentThemeName {
    switch (_currentThemeMode) {
      case AppThemeMode.readLeafLight:
        return 'Light';
      case AppThemeMode.classicLight:
        return 'Luminous';
      case AppThemeMode.mysteriousDark:
        return 'Dark';
      case AppThemeMode.classicDark:
        return 'Archaic';
      case AppThemeMode.oceanBlue:
        return 'Ocean';
      case AppThemeMode.darkForest:
        return 'Forest';
      case AppThemeMode.pinkCutesy:
        return 'Cutesy';
      case AppThemeMode.midNight:
        return 'Midnight';
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

  void setSystemTheme() {
    _useSystemTheme = true;
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    final newMode = brightness == Brightness.dark
        ? AppThemeMode.mysteriousDark
        : AppThemeMode.readLeafLight;

    // Store as last used theme before switching
    if (brightness == Brightness.dark) {
      _lastDarkTheme = newMode;
    } else {
      _lastLightTheme = newMode;
    }

    _currentThemeMode = newMode;
    _updateTheme();
    _savePreferences();
    notifyListeners();
  }

  // Override setThemeMode to disable system theme when manually selecting a theme
  @override
  void setThemeMode(AppThemeMode mode) {
    _useSystemTheme = false;
    // Store the last used theme for each mode
    if (mode == AppThemeMode.mysteriousDark ||
        mode == AppThemeMode.classicDark ||
        mode == AppThemeMode.darkForest) {
      _lastDarkTheme = mode;
    } else {
      _lastLightTheme = mode;
    }

    _currentThemeMode = mode;
    _updateTheme();
    _savePreferences();
  }

  void _updateTheme() {
    switch (_currentThemeMode) {
      case AppThemeMode.classicLight:
        _theme = classicLightTheme;
        break;
      case AppThemeMode.readLeafLight:
        _theme = _lightTheme;
        break;
      case AppThemeMode.mysteriousDark:
        _theme = _indigoNightTheme;
        break;
      case AppThemeMode.classicDark:
        _theme = _darkTheme;
        break;
      case AppThemeMode.oceanBlue:
        _theme = oceanBlueTheme;
        break;
      case AppThemeMode.darkForest:
        _theme = darkForestTheme;
        break;
      case AppThemeMode.pinkCutesy:
        _theme = pinkCutesyTheme;
        break;
      case AppThemeMode.midNight:
        _theme = _midNightTheme;
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

  // Add getters for last used themes
  AppThemeMode? get lastLightTheme => _lastLightTheme;
  AppThemeMode? get lastDarkTheme => _lastDarkTheme;

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

  static final _indigoNightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Primary brand / accent color: deep indigo
    primaryColor: const Color(0xFF433E8A),

    // Pure black background
    scaffoldBackgroundColor: Colors.black,

    // Surfaces & cards slightly off-black
    cardColor: const Color(0xFF0A0A0A),
    dividerColor: const Color(0xFF1F1F1F),
    hintColor: const Color(0xFF6F6BAE), // Softened indigo for hints
    highlightColor:
        const Color(0xFF5C58A7), // Another indigo variant for highlights

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF433E8A), // Deep indigo
      secondary: Color(0xFF6F6BAE), // Lighter indigo accent
      tertiary: Color(0xFFA29FDC), // Subtle lavender-ish for variety
      surface: Color(0xFF0A0A0A), // Off-black for cards, etc.
      background: Color(0xFF000000), // Pure black
      error: Color(0xFFCF6679),
      onPrimary: Color(0xFFFFFFFF), // White text on indigo
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFE6E6E6), // Light grey text on black surfaces
      onBackground: Color(0xFFE6E6E6),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFF433E8A), // Tints for M3 surfaces
      // Containers in deeper or lighter indigo variants:
      primaryContainer: Color(0xFF353165),
      secondaryContainer: Color(0xFF5C58A7),
      tertiaryContainer: Color(0xFF403C6C),
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black, // Matches scaffold
      foregroundColor: Color(0xFFE6E6E6), // Light text/icons
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFE6E6E6)),
      titleTextStyle: TextStyle(
        color: Color(0xFFE6E6E6),
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
        color: Color(0xFFE6E6E6),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 14,
      ),
      titleLarge: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: Color(0xFFB3B3B3),
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        color: Color(0xFFB3B3B3),
        fontSize: 11,
      ),
    ),

    // Icon theme
    iconTheme: const IconThemeData(
      color: Color(0xFFE6E6E6),
      size: 24,
    ),

    // Navigation bar theme
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.black,
      indicatorColor: const Color(0xFF433E8A).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE6E6E6),
        ),
      ),
    ),

    // Card theme
    cardTheme: CardTheme(
      color: const Color(0xFF0A0A0A),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Dialog theme
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A0A0A),
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
          color: Color(0xFF433E8A),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
    ),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: Color(0xFF1F1F1F),
      thickness: 1,
      space: 1,
    ),

    // Floating Action Button theme
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF433E8A),
      foregroundColor: Color(0xFFFFFFFF),
    ),

    // Checkbox theme
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF433E8A);
        }
        return const Color(0xFF1F1F1F);
      }),
    ),

    // Radio theme
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF433E8A);
        }
        return const Color(0xFF1F1F1F);
      }),
    ),

    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF433E8A);
        }
        return const Color(0xFF444444);
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF433E8A).withOpacity(0.5);
        }
        return const Color(0xFF444444).withOpacity(0.3);
      }),
    ),

    // Progress indicator theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF433E8A),
    ),

    // Chip theme
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF0A0A0A),
      selectedColor: const Color(0xFF433E8A).withOpacity(0.2),
      disabledColor: const Color(0xFF444444),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Color(0xFFE6E6E6)),
    ),

    // Custom color extensions
    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Color(0xFF0A0A0A),
        fileCardText: Color(0xFFE6E6E6),
        aiMessageBackground: Color(0xFF0A0A0A),
        aiMessageText: Color(0xFFD0D0D0),
        minimalFileCardBackground: Color(0xFF0A0A0A),
        minimalFileCardText: Color(0xFFE6E6E6),
      ),
    ],
  );

  static final classicLightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.white,
    cardColor:
        const Color(0xFFF8F8F8), // Slightly off-white for better contrast
    dividerColor:
        const Color(0xFFD6D6D6), // Slightly darker for better visibility
    hintColor: Colors.grey,
    highlightColor: const Color(0xFFFE2C55), // Vibrant TikTok red/pink accent

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1A1A1A), // Slightly darker black for better contrast
      secondary: Color(0xFFFE2C55), // TikTok accent color
      tertiary: Color(0xFFFF8787), // Additional pinkish accent
      background: Colors.white,
      surface: Colors.white,
      error: Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
      surfaceTint: Colors.black,
      primaryContainer: Color(0xFFE0E0E0), // More visible gray tone
      secondaryContainer: Color(0xFFFFD1D9), // Warmer pink tone
      tertiaryContainer: Color(0xFFFFE3E3),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.black, fontSize: 14),
      titleLarge: TextStyle(
          color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(
          color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
    ),

    iconTheme: const IconThemeData(color: Colors.black, size: 24),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFE2C55).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black),
      ),
    ),

    cardTheme: CardTheme(
      color: const Color(0xFFF8F8F8), // Subtle contrast with white background
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.grey),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFD6D6D6),
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFE2C55),
      foregroundColor: Colors.white,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFE2C55);
        }
        return Colors.grey;
      }),
    ),

    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFE2C55);
        }
        return Colors.grey;
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFE2C55);
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFE2C55).withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),

    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFFFE2C55)),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF9F9F9),
      selectedColor: const Color(0xFFFE2C55).withOpacity(0.2),
      disabledColor: Colors.grey.withOpacity(0.3),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Colors.black),
    ),

    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Color(0xFFF8F8F8),
        fileCardText: Colors.black,
        aiMessageBackground: Color(0xFFF9F9F9),
        aiMessageText: Colors.black,
        minimalFileCardBackground: Color(0xFFF8F8F8),
        minimalFileCardText: Colors.black,
      ),
    ],
  );

  static final oceanBlueTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    primaryColor: const Color(0xFF0288D1), // Ocean blue
    scaffoldBackgroundColor: const Color(0xFFF0F8FA), // Light aqua background
    cardColor: Colors.white,
    dividerColor: const Color(0xFFB2EBF2),
    hintColor: const Color(0xFF4DD0E1), // Lighter teal hint
    highlightColor: const Color(0xFF0288D1),

    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0288D1),
      secondary: Color(0xFF81D4FA), // Soft sky-blue accent
      tertiary: Color(0xFF4DD0E1), // Teal accent
      background: Color(0xFFF0F8FA),
      surface: Colors.white,
      error: Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
      surfaceTint: Color(0xFF0288D1),
      primaryContainer: Color(0xFFB3E5FC),
      secondaryContainer: Color(0xFFBBDEFB),
      tertiaryContainer: Color(0xFFB2EBF2),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF0F8FA),
      foregroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.black, fontSize: 14),
      titleLarge: TextStyle(
          color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(
          color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
    ),

    iconTheme: const IconThemeData(color: Colors.black, size: 24),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFF0F8FA),
      indicatorColor: const Color(0xFF0288D1).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black),
      ),
    ),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFE1F5FE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF4DD0E1)),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFB2EBF2),
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0288D1),
      foregroundColor: Colors.white,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF0288D1);
        }
        return Colors.grey;
      }),
    ),

    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF0288D1);
        }
        return Colors.grey;
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF0288D1);
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF0288D1).withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),

    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFF0288D1)),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE1F5FE),
      selectedColor: const Color(0xFF0288D1).withOpacity(0.2),
      disabledColor: Colors.grey.withOpacity(0.3),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Colors.black),
    ),

    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Colors.white,
        fileCardText: Colors.black,
        aiMessageBackground: Color(0xFFE1F5FE),
        aiMessageText: Colors.black,
        minimalFileCardBackground: Colors.white,
        minimalFileCardText: Colors.black,
      ),
    ],
  );

  static final darkForestTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    primaryColor: const Color(0xFF2E4E3F), // Forest green
    scaffoldBackgroundColor:
        const Color(0xFF0B1F16), // Very dark, greenish black
    cardColor: const Color(0xFF16281F), // Slightly lighter forest tone
    dividerColor: const Color(0xFF1F3329),
    hintColor: const Color(0xFF4B3A2B), // A hint of earthy brown
    highlightColor: const Color(0xFF2E4E3F),

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2E4E3F),
      secondary: Color(0xFF614D3B), // Warm brown accent
      tertiary: Color(0xFF8C6E54), // Lighter wood tone
      surface: Color(0xFF16281F),
      background: Color(0xFF0B1F16),
      error: Color(0xFFCF6679),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFFD0D0D0),
      onBackground: Color(0xFFD0D0D0),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFF2E4E3F),
      primaryContainer: Color(0xFF264033),
      secondaryContainer: Color(0xFF4B3A2B),
      tertiaryContainer: Color(0xFF3A2C20),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B1F16),
      foregroundColor: Color(0xFFD0D0D0),
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFD0D0D0)),
      titleTextStyle: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Color(0xFFD0D0D0), fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Color(0xFFD0D0D0), fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFFD0D0D0), fontSize: 16),
      bodyMedium: TextStyle(color: Color(0xFFD0D0D0), fontSize: 14),
      titleLarge: TextStyle(
          color: Color(0xFFD0D0D0), fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Color(0xFFD0D0D0), fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(
          color: Color(0xFFD0D0D0), fontSize: 14, fontWeight: FontWeight.w500),
    ),

    iconTheme: const IconThemeData(color: Color(0xFFD0D0D0), size: 24),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0B1F16),
      indicatorColor: const Color(0xFF2E4E3F).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD0D0D0)),
      ),
    ),

    cardTheme: CardTheme(
      color: const Color(0xFF16281F),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF16281F),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF16281F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF4B3A2B)),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF1F3329),
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2E4E3F),
      foregroundColor: Color(0xFFFFFFFF),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF2E4E3F);
        }
        return const Color(0xFF1F3329);
      }),
    ),

    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF2E4E3F);
        }
        return const Color(0xFF1F3329);
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF2E4E3F);
        }
        return const Color(0xFF444444);
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF2E4E3F).withOpacity(0.5);
        }
        return const Color(0xFF444444).withOpacity(0.3);
      }),
    ),

    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFF2E4E3F)),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF16281F),
      selectedColor: const Color(0xFF2E4E3F).withOpacity(0.2),
      disabledColor: const Color(0xFF444444),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Color(0xFFD0D0D0)),
    ),

    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Color(0xFF16281F),
        fileCardText: Color(0xFFD0D0D0),
        aiMessageBackground: Color(0xFF16281F),
        aiMessageText: Color(0xFFD0D0D0),
        minimalFileCardBackground: Color(0xFF16281F),
        minimalFileCardText: Color(0xFFD0D0D0),
      ),
    ],
  );

  static final pinkCutesyTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    primaryColor: const Color(0xFFFF8FAB), // Main pink accent
    scaffoldBackgroundColor: const Color(0xFFFFE4EC), // Pastel pink background
    cardColor: Colors.white,
    dividerColor: const Color(0xFFFFC2D1),
    hintColor: const Color(0xFFFFAFC7), // Slightly deeper pink
    highlightColor: const Color(0xFFFF8FAB),

    colorScheme: const ColorScheme.light(
      primary: Color(0xFFFF8FAB),
      secondary: Color(0xFFFFD3DD),
      tertiary: Color(0xFFFFE4EC),
      background: Color(0xFFFFE4EC),
      surface: Colors.white,
      error: Color(0xFFB00020),
      onPrimary: Color(0xFFFFFFFF), // White text on pink
      onSecondary: Color(0xFF1B1B1B), // Dark text on lighter pink
      onSurface: Color(0xFF1B1B1B),
      onBackground: Color(0xFF1B1B1B),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFFFF8FAB),
      primaryContainer: Color(0xFFFFC2D1),
      secondaryContainer: Color(0xFFFFEBF1),
      tertiaryContainer: Color(0xFFFFF5F7),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFE4EC),
      foregroundColor: Color(0xFF1B1B1B),
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF1B1B1B)),
      titleTextStyle: TextStyle(
        color: Color(0xFF1B1B1B),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      surfaceTintColor: Colors.transparent,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
          color: Color(0xFF1B1B1B), fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: Color(0xFF1B1B1B), fontSize: 28, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Color(0xFF1B1B1B), fontSize: 16),
      bodyMedium: TextStyle(color: Color(0xFF1B1B1B), fontSize: 14),
      titleLarge: TextStyle(
          color: Color(0xFF1B1B1B), fontSize: 20, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(
          color: Color(0xFF1B1B1B), fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(
          color: Color(0xFF1B1B1B), fontSize: 14, fontWeight: FontWeight.w500),
    ),

    iconTheme: const IconThemeData(color: Color(0xFF1B1B1B), size: 24),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFFFE4EC),
      indicatorColor: const Color(0xFFFF8FAB).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1B1B1B)),
      ),
    ),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFEBF1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFFFFAFC7)),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFFFC2D1),
      thickness: 1,
      space: 1,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFF8FAB),
      foregroundColor: Color(0xFFFFFFFF),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFF8FAB);
        }
        return Colors.grey;
      }),
    ),

    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFF8FAB);
        }
        return Colors.grey;
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFF8FAB);
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFFFF8FAB).withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),

    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFFFF8FAB)),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFFFEBF1),
      selectedColor: const Color(0xFFFF8FAB).withOpacity(0.2),
      disabledColor: Colors.grey.withOpacity(0.3),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Color(0xFF1B1B1B)),
    ),

    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Colors.white,
        fileCardText: Color(0xFF1B1B1B),
        aiMessageBackground: Color(0xFFFFEBF1),
        aiMessageText: Color(0xFF1B1B1B),
        minimalFileCardBackground: Colors.white,
        minimalFileCardText: Color(0xFF1B1B1B),
      ),
    ],
  );

  static final _midNightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    //
    // Primary (lighter purple) so text/icons using "primary" stand out clearly
    //
    primaryColor: const Color(0xFF9F6CD2), // Lighter purple accent

    //
    // Most widget backgrounds revolve around #15032C (Sapphire)
    //
    scaffoldBackgroundColor: const Color(0xFF15032C),
    cardColor:
        const Color(0xFF1E062E), // Slightly lighter than #15032C for contrast
    dividerColor: const Color(0xFF321246),
    hintColor: const Color(0xFF808080), // Neutral grey hint
    highlightColor: const Color(0xFF270652), // Deep purple highlight

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF9F6CD2), // Lighter purple accent
      secondary: Color(0xFFC7A7E3), // A complementary lighter purple
      tertiary: Color(0xFFE1C6F7), // Subtle pastel purple
      background: Color(0xFF15032C), // Sapphire background
      surface: Color(0xFF15032C), // Same for surfaces to unify the "night" feel
      error: Color(0xFFCF6679),
      onPrimary:
          Colors.black, // Text on the lighter purple is black for contrast
      onSecondary: Colors.black,
      onSurface: Color(0xFFE6E6E6),
      onBackground: Color(0xFFE6E6E6),
      onError: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFF9F6CD2),
      // Container variants
      primaryContainer: Color(0xFFBFA1E5),
      secondaryContainer: Color(0xFFD8C4F1),
      tertiaryContainer: Color(0xFFF1E3FD),
    ),

    //
    // AppBar theme
    //
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF15032C),
      foregroundColor: Color(0xFFE6E6E6),
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFE6E6E6)),
      titleTextStyle: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),

    //
    // Text themes
    //
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 14,
      ),
      titleLarge: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: Color(0xFFE6E6E6),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        color: Color(0xFFD0D0D0),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: Color(0xFFB3B3B3),
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        color: Color(0xFFB3B3B3),
        fontSize: 11,
      ),
    ),

    //
    // Icon theme
    //
    iconTheme: const IconThemeData(
      color: Color(0xFFE6E6E6),
      size: 24,
    ),

    //
    // Navigation bar theme
    //
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF15032C),
      indicatorColor: const Color(0xFF9F6CD2).withOpacity(0.2),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE6E6E6),
        ),
      ),
    ),

    //
    // Card theme
    //
    cardTheme: CardTheme(
      color: const Color(0xFF1E062E),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    //
    // Dialog theme
    //
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E062E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    //
    // Input decoration theme
    //
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF15032C),
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
          color: Color(0xFF9F6CD2), // Use the lighter purple accent
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF808080)),
    ),

    //
    // Divider theme
    //
    dividerTheme: const DividerThemeData(
      color: Color(0xFF321246),
      thickness: 1,
      space: 1,
    ),

    //
    // Floating Action Button theme
    //
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF9F6CD2),
      foregroundColor: Colors.black,
    ),

    //
    // Checkbox theme
    //
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF9F6CD2);
        }
        return const Color(0xFF321246);
      }),
    ),

    //
    // Radio theme
    //
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF9F6CD2);
        }
        return const Color(0xFF321246);
      }),
    ),

    //
    // Switch theme
    //
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF9F6CD2);
        }
        return const Color(0xFF444444);
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return const Color(0xFF9F6CD2).withOpacity(0.5);
        }
        return const Color(0xFF444444).withOpacity(0.3);
      }),
    ),

    //
    // Progress indicator theme
    //
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF9F6CD2),
    ),

    //
    // Chip theme
    //
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF15032C),
      selectedColor: const Color(0xFF9F6CD2).withOpacity(0.2),
      disabledColor: const Color(0xFF444444),
      padding: const EdgeInsets.all(8),
      labelStyle: const TextStyle(color: Color(0xFFE6E6E6)),
    ),

    //
    // Custom color extensions for file cards and AI messages
    // (Everything using #15032C so it all blends nicely)
    //
    extensions: [
      const CustomThemeExtension(
        fileCardBackground: Color(0xFF15032C),
        fileCardText: Color(0xFFE6E6E6),
        aiMessageBackground: Color(0xFF15032C),
        aiMessageText: Color(0xFFD0D0D0),
        minimalFileCardBackground: Color(0xFF15032C),
        minimalFileCardText: Color(0xFFE6E6E6),
      ),
    ],
  );

  // Add getter to check if theme is dark
  bool get isDarkMode {
    return _currentThemeMode == AppThemeMode.mysteriousDark ||
        _currentThemeMode == AppThemeMode.classicDark ||
        _currentThemeMode == AppThemeMode.darkForest ||
        _currentThemeMode == AppThemeMode.midNight;
  }

  // Add method to toggle between last used light/dark themes
  void toggleTheme() {
    if (isDarkMode) {
      // Currently dark, switch to last light theme or default to Light theme
      setThemeMode(_lastLightTheme ?? AppThemeMode.readLeafLight);
    } else {
      // Currently light, switch to last dark theme or default to Dark theme
      setThemeMode(_lastDarkTheme ?? AppThemeMode.mysteriousDark);
    }
  }

  Future<void> setShowReadingReminders(bool value) async {
    _showReadingReminders = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_reading_reminders', value);
    notifyListeners();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showReadingReminders = prefs.getBool('show_reading_reminders') ?? true;
    // ... load other settings ...
    notifyListeners();
  }
}
