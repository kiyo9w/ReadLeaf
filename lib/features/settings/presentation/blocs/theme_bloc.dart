import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:read_leaf/features/settings/data/sync/user_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:read_leaf/core/themes/custom_theme_extension.dart';

// Theme Events
abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeInitialized extends ThemeEvent {}

class ThemeToggled extends ThemeEvent {}

class ThemeModeChanged extends ThemeEvent {
  final AppThemeMode themeMode;

  const ThemeModeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class SystemThemeToggled extends ThemeEvent {
  final bool useSystemTheme;

  const SystemThemeToggled(this.useSystemTheme);

  @override
  List<Object?> get props => [useSystemTheme];
}

// Add the two new events
class SystemThemeEnabled extends ThemeEvent {}

class SystemThemeChanged extends ThemeEvent {
  final AppThemeMode themeMode;

  const SystemThemeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

// Theme State
class ThemeState extends Equatable {
  final ThemeData theme;
  final bool isDarkMode;
  final AppThemeMode currentThemeMode;
  final bool useSystemTheme;
  final AppThemeMode? lastLightTheme;
  final AppThemeMode? lastDarkTheme;
  final String currentThemeName;

  const ThemeState({
    required this.theme,
    required this.isDarkMode,
    required this.currentThemeMode,
    required this.useSystemTheme,
    this.lastLightTheme,
    this.lastDarkTheme,
    required this.currentThemeName,
  });

  @override
  List<Object?> get props => [
        theme,
        isDarkMode,
        currentThemeMode,
        useSystemTheme,
        lastLightTheme,
        lastDarkTheme,
        currentThemeName,
      ];

  ThemeState copyWith({
    ThemeData? theme,
    bool? isDarkMode,
    AppThemeMode? currentThemeMode,
    bool? useSystemTheme,
    AppThemeMode? lastLightTheme,
    AppThemeMode? lastDarkTheme,
    String? currentThemeName,
  }) {
    return ThemeState(
      theme: theme ?? this.theme,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currentThemeMode: currentThemeMode ?? this.currentThemeMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      lastLightTheme: lastLightTheme ?? this.lastLightTheme,
      lastDarkTheme: lastDarkTheme ?? this.lastDarkTheme,
      currentThemeName: currentThemeName ?? this.currentThemeName,
    );
  }
}

// App Theme Mode enum definition (copied from ThemeProvider)
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

// Theme Bloc
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final UserPreferencesService _userPreferencesService;

  ThemeBloc(this._userPreferencesService)
      : super(ThemeState(
          theme: _getLightTheme(),
          isDarkMode: false,
          currentThemeMode: AppThemeMode.readLeafLight,
          useSystemTheme: false,
          currentThemeName: 'Light',
        )) {
    on<ThemeInitialized>(_onInitialized);
    on<ThemeToggled>(_onThemeToggled);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<SystemThemeToggled>(_onSystemThemeToggled);
    on<SystemThemeEnabled>(_onSystemThemeEnabled);
    on<SystemThemeChanged>(_onSystemThemeChanged);

    // Initialize theme
    add(ThemeInitialized());
  }

  Future<void> _onInitialized(
      ThemeInitialized event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved theme settings
    final useSystemTheme = prefs.getBool('use_system_theme') ?? false;
    final savedThemeMode =
        prefs.getString('theme_mode') ?? AppThemeMode.readLeafLight.toString();
    final lastLightTheme = prefs.getString('last_light_theme');
    final lastDarkTheme = prefs.getString('last_dark_theme');

    // Parse the saved theme mode
    AppThemeMode currentThemeMode;
    try {
      currentThemeMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == savedThemeMode,
        orElse: () => AppThemeMode.readLeafLight,
      );
    } catch (_) {
      currentThemeMode = AppThemeMode.readLeafLight;
    }

    // Parse last used light/dark themes
    AppThemeMode? parsedLastLightTheme;
    if (lastLightTheme != null) {
      try {
        parsedLastLightTheme = AppThemeMode.values.firstWhere(
          (e) => e.toString() == lastLightTheme,
        );
      } catch (_) {
        parsedLastLightTheme = AppThemeMode.readLeafLight;
      }
    }

    AppThemeMode? parsedLastDarkTheme;
    if (lastDarkTheme != null) {
      try {
        parsedLastDarkTheme = AppThemeMode.values.firstWhere(
          (e) => e.toString() == lastDarkTheme,
        );
      } catch (_) {
        parsedLastDarkTheme = AppThemeMode.mysteriousDark;
      }
    }

    // Determine if we should use system theme
    if (useSystemTheme) {
      // Get the system brightness
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;

      // Use appropriate theme based on system brightness
      final themeMode = isDark
          ? (parsedLastDarkTheme ?? AppThemeMode.mysteriousDark)
          : (parsedLastLightTheme ?? AppThemeMode.readLeafLight);

      emit(state.copyWith(
        theme: _getThemeData(themeMode),
        isDarkMode: _isDarkTheme(themeMode),
        currentThemeMode: themeMode,
        useSystemTheme: true,
        lastLightTheme: parsedLastLightTheme,
        lastDarkTheme: parsedLastDarkTheme,
        currentThemeName: _getThemeName(themeMode),
      ));
    } else {
      // Use the explicitly set theme
      emit(state.copyWith(
        theme: _getThemeData(currentThemeMode),
        isDarkMode: _isDarkTheme(currentThemeMode),
        currentThemeMode: currentThemeMode,
        useSystemTheme: false,
        lastLightTheme: parsedLastLightTheme,
        lastDarkTheme: parsedLastDarkTheme,
        currentThemeName: _getThemeName(currentThemeMode),
      ));
    }

    // Sync with user preferences if available
    try {
      final prefs = _userPreferencesService.getPreferences();
      final customSettings = {
        ...prefs.customSettings,
        'theme_mode': state.currentThemeMode.toString(),
        'use_system_theme': state.useSystemTheme.toString(),
      };

      await _userPreferencesService
          .savePreferences(prefs.copyWith(customSettings: customSettings));
    } catch (_) {
      // Continue if user preferences service fails
    }
  }

  Future<void> _onThemeToggled(
      ThemeToggled event, Emitter<ThemeState> emit) async {
    // Toggle between light and dark themes
    AppThemeMode newThemeMode;

    if (state.isDarkMode) {
      // Switch to light theme
      newThemeMode = state.lastLightTheme ?? AppThemeMode.readLeafLight;
    } else {
      // Switch to dark theme
      newThemeMode = state.lastDarkTheme ?? AppThemeMode.mysteriousDark;
    }

    await _saveThemeMode(newThemeMode);

    emit(state.copyWith(
      theme: _getThemeData(newThemeMode),
      isDarkMode: _isDarkTheme(newThemeMode),
      currentThemeMode: newThemeMode,
      useSystemTheme: false,
      currentThemeName: _getThemeName(newThemeMode),
    ));
  }

  Future<void> _onThemeModeChanged(
      ThemeModeChanged event, Emitter<ThemeState> emit) async {
    final newThemeMode = event.themeMode;
    final isDark = _isDarkTheme(newThemeMode);

    // Update last light/dark theme references
    AppThemeMode? updatedLastLightTheme = state.lastLightTheme;
    AppThemeMode? updatedLastDarkTheme = state.lastDarkTheme;

    if (isDark) {
      updatedLastDarkTheme = newThemeMode;
    } else {
      updatedLastLightTheme = newThemeMode;
    }

    await _saveThemeMode(newThemeMode);
    await _saveLastThemes(updatedLastLightTheme, updatedLastDarkTheme);
    await _saveUseSystemTheme(
        false); // Always save this when manually changing theme

    // First emit that we're turning system theme off explicitly
    if (state.useSystemTheme) {
      emit(state.copyWith(
        useSystemTheme: false,
      ));
    }

    // Then emit the theme change
    emit(state.copyWith(
      theme: _getThemeData(newThemeMode),
      isDarkMode: isDark,
      currentThemeMode: newThemeMode,
      useSystemTheme: false, // Explicitly set to false here
      lastLightTheme: updatedLastLightTheme,
      lastDarkTheme: updatedLastDarkTheme,
      currentThemeName: _getThemeName(newThemeMode),
    ));
  }

  Future<void> _onSystemThemeToggled(
      SystemThemeToggled event, Emitter<ThemeState> emit) async {
    final useSystemTheme = event.useSystemTheme;

    await _saveUseSystemTheme(useSystemTheme);

    // First emit just the system theme toggle change to immediately update UI
    emit(state.copyWith(
      useSystemTheme: useSystemTheme,
    ));

    if (useSystemTheme) {
      // Get system brightness
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final isDark = brightness == Brightness.dark;

      // Use appropriate theme based on system brightness
      final themeMode = isDark
          ? (state.lastDarkTheme ?? AppThemeMode.mysteriousDark)
          : (state.lastLightTheme ?? AppThemeMode.readLeafLight);

      // Then emit the theme change
      emit(state.copyWith(
        theme: _getThemeData(themeMode),
        isDarkMode: _isDarkTheme(themeMode),
        currentThemeMode: themeMode,
        useSystemTheme: true,
        currentThemeName: _getThemeName(themeMode),
      ));
    }
    // If turning off system theme, keep current theme, no need for a second emit
  }

  Future<void> _onSystemThemeEnabled(
      SystemThemeEnabled event, Emitter<ThemeState> emit) async {
    // Enable system theme
    await _saveUseSystemTheme(true);

    // Get the system brightness
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;

    // Use appropriate theme based on system brightness
    final themeMode = isDark
        ? (state.lastDarkTheme ?? AppThemeMode.mysteriousDark)
        : (state.lastLightTheme ?? AppThemeMode.readLeafLight);

    // First emit that we're turning system theme on explicitly
    if (!state.useSystemTheme) {
      emit(state.copyWith(
        useSystemTheme: true,
      ));
    }

    // Then emit the theme change
    emit(state.copyWith(
      theme: _getThemeData(themeMode),
      isDarkMode: _isDarkTheme(themeMode),
      currentThemeMode: themeMode,
      useSystemTheme: true, // Ensure this is set explicitly
      currentThemeName: _getThemeName(themeMode),
    ));
  }

  Future<void> _onSystemThemeChanged(
      SystemThemeChanged event, Emitter<ThemeState> emit) async {
    final newThemeMode = event.themeMode;
    final isDark = _isDarkTheme(newThemeMode);

    // Update last light/dark theme references
    AppThemeMode? updatedLastLightTheme = state.lastLightTheme;
    AppThemeMode? updatedLastDarkTheme = state.lastDarkTheme;

    if (isDark) {
      updatedLastDarkTheme = newThemeMode;
    } else {
      updatedLastLightTheme = newThemeMode;
    }

    await _saveThemeMode(newThemeMode);
    await _saveLastThemes(updatedLastLightTheme, updatedLastDarkTheme);
    await _saveUseSystemTheme(false);

    emit(state.copyWith(
      theme: _getThemeData(newThemeMode),
      isDarkMode: isDark,
      currentThemeMode: newThemeMode,
      useSystemTheme: false,
      lastLightTheme: updatedLastLightTheme,
      lastDarkTheme: updatedLastDarkTheme,
      currentThemeName: _getThemeName(newThemeMode),
    ));
  }

  // Helper methods

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());

    try {
      final prefs = _userPreferencesService.getPreferences();
      final customSettings = {
        ...prefs.customSettings,
        'theme_mode': mode.toString(),
      };

      await _userPreferencesService
          .savePreferences(prefs.copyWith(customSettings: customSettings));
    } catch (_) {
      // Continue if user preferences service fails
    }
  }

  Future<void> _saveLastThemes(
      AppThemeMode? lightTheme, AppThemeMode? darkTheme) async {
    final prefs = await SharedPreferences.getInstance();

    if (lightTheme != null) {
      await prefs.setString('last_light_theme', lightTheme.toString());
    }

    if (darkTheme != null) {
      await prefs.setString('last_dark_theme', darkTheme.toString());
    }

    try {
      final prefs = _userPreferencesService.getPreferences();
      final customSettings = {
        ...prefs.customSettings,
      };

      if (lightTheme != null) {
        customSettings['last_light_theme'] = lightTheme.toString();
      }

      if (darkTheme != null) {
        customSettings['last_dark_theme'] = darkTheme.toString();
      }

      await _userPreferencesService
          .savePreferences(prefs.copyWith(customSettings: customSettings));
    } catch (_) {
      // Continue if user preferences service fails
    }
  }

  Future<void> _saveUseSystemTheme(bool useSystemTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_system_theme', useSystemTheme);

    try {
      final prefs = _userPreferencesService.getPreferences();
      final customSettings = {
        ...prefs.customSettings,
        'use_system_theme': useSystemTheme.toString(),
      };

      await _userPreferencesService
          .savePreferences(prefs.copyWith(customSettings: customSettings));
    } catch (_) {
      // Continue if user preferences service fails
    }
  }

  bool _isDarkTheme(AppThemeMode mode) {
    return mode == AppThemeMode.mysteriousDark ||
        mode == AppThemeMode.classicDark ||
        mode == AppThemeMode.darkForest ||
        mode == AppThemeMode.midNight;
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.readLeafLight:
        return 'Light';
      case AppThemeMode.classicLight:
        return 'Luminous';
      case AppThemeMode.oceanBlue:
        return 'Ocean';
      case AppThemeMode.mysteriousDark:
        return 'Dark';
      case AppThemeMode.classicDark:
        return 'Archaic';
      case AppThemeMode.darkForest:
        return 'Forest';
      case AppThemeMode.pinkCutesy:
        return 'Candy';
      case AppThemeMode.midNight:
        return 'Midnight';
      default:
        return 'Light';
    }
  }

  // Placeholder method for theme data
  static ThemeData _getThemeData(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.readLeafLight:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFF6B8F71), // Soft sage/olive green
          scaffoldBackgroundColor: const Color(0xFFF5F2ED), // Warm off-white
          cardColor: Colors.white,
          dividerColor: const Color(0xFFE0E0E0),
          hintColor: const Color(0xFF8C9A76), // Subtle greenish hint
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6B8F71), // Sage/Olive
            secondary: Color(0xFFB5A89E), // Warm neutral
            tertiary: Color(0xFFE9CFA3), // Light, warm golden
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFBA1A1A),
            onPrimary: Color(0xFFFFFFFF),
            onSecondary: Color(0xFF1B1B1B),
            onSurface: Color(0xFF1B1B1B),
            onError: Color(0xFFFFFFFF),
            surfaceTint: Color(0xFF6B8F71), // Tint surfaces with sage
            primaryContainer: Color(0xFFC4D9C7), // Lighter sage for containers
            secondaryContainer: Color(0xFFD9D2CB), // Lighter warm neutral
            tertiaryContainer: Color(0xFFF3E2CC), // Lighter golden accent
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F2ED), // Same as scaffold
            foregroundColor: Colors.black87,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black87),
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.black87, fontSize: 14),
            titleLarge: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(
            color: Colors.black87,
            size: 24,
          ),
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

      case AppThemeMode.classicLight:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: Colors.black,
          scaffoldBackgroundColor: Colors.white,
          cardColor: const Color(0xFFF8F8F8), // Slightly off-white for cards
          dividerColor: const Color(0xFFD6D6D6),
          hintColor: Colors.grey,
          colorScheme: ColorScheme.light(
            primary: Colors.black,
            secondary:
                const Color(0xFFFE2C55), // Vibrant TikTok red/pink accent
            surface: Colors.white,
            error: const Color(0xFFB00020),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
          ),
          cardTheme: CardTheme(
            color: const Color(0xFFF8F8F8),
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

      case AppThemeMode.oceanBlue:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFF0288D1), // Ocean blue
          scaffoldBackgroundColor:
              const Color(0xFFF0F8FA), // Light aqua background
          cardColor: Colors.white,
          dividerColor: const Color(0xFFB2EBF2),
          hintColor: const Color(0xFF4DD0E1), // Lighter teal hint
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0288D1),
            secondary: Color(0xFF81D4FA), // Soft sky-blue accent
            tertiary: Color(0xFF4DD0E1),
            primaryContainer: Color(0xFFB3E5FC),
            secondaryContainer: Color(0xFFBBDEFB),
            tertiaryContainer: Color(0xFFB2EBF2),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF0F8FA),
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

      case AppThemeMode.pinkCutesy:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFFFF8FAB),
          scaffoldBackgroundColor: const Color(0xFFFFE4EC),
          cardColor: const Color(0xFFF7F6F5), // Near-white card
          dividerColor: const Color(0xFFDDD1E9), // Lavender-like
          hintColor: const Color(0xFFFF8FAB),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF8FAB),
            secondary: Color(0xFFFFAFC7),
            primaryContainer: Color(0xFFFFD3DD),
            secondaryContainer: Color(0xFFFFC2D1),
            tertiaryContainer: Color(0xFFFFEBF1),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFE4EC),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFFF7F6F5),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          extensions: [
            const CustomThemeExtension(
              fileCardBackground: Color(0xFFF7F6F5),
              fileCardText: Color(0xFF1B1B1B),
              aiMessageBackground: Color(0xFFF0DFEA),
              aiMessageText: Color(0xFF1B1B1B),
              minimalFileCardBackground: Color(0xFFF7F6F5),
              minimalFileCardText: Color(0xFF1B1B1B),
            ),
          ],
        );

      case AppThemeMode.mysteriousDark:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF433E8A), // Deep indigo
          scaffoldBackgroundColor: Colors.black,
          cardColor: const Color(0xFF0A0A0A), // Slightly off-black
          dividerColor: const Color(0xFF1F1F1F),
          hintColor: const Color(0xFF6F6BAE), // Softened indigo for hints
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF433E8A), // Deep indigo
            secondary: Color(0xFF6F6BAE), // Lighter indigo accent
            tertiary: Color(0xFFA29FDC), // Subtle lavender-ish for variety
            primaryContainer: Color(0xFF353165),
            secondaryContainer: Color(0xFF5C58A7),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Color(0xFFE6E6E6),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF0A0A0A),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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

      case AppThemeMode.classicDark:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor:
              const Color(0xFF2E4E3F), // Forest green (matching old theme)
          scaffoldBackgroundColor:
              const Color(0xFF0B1F16), // Very dark, greenish black
          cardColor: const Color(0xFF16281F), // Slightly lighter forest tone
          dividerColor: const Color(0xFF1F3329),
          hintColor: const Color(0xFF4B3A2B), // Earthy brown hint
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2E4E3F),
            secondary: Color(0xFF4B3A2B),
            primaryContainer: Color(0xFF1F3329),
            secondaryContainer: Color(0xFF264033),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B1F16),
            foregroundColor: Color(0xFFD0D0D0),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF16281F),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          extensions: [
            const CustomThemeExtension(
              fileCardBackground: Color(0xFF16281F),
              fileCardText: Color(0xFFD0D0D0),
              aiMessageBackground: Color(0xFF0B1F16),
              aiMessageText: Color(0xFFD0D0D0),
              minimalFileCardBackground: Color(0xFF16281F),
              minimalFileCardText: Color(0xFFD0D0D0),
            ),
          ],
        );

      case AppThemeMode.darkForest:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF2E4E3F), // Forest green
          scaffoldBackgroundColor:
              const Color(0xFF0B1F16), // Very dark, greenish black
          cardColor: const Color(0xFF16281F), // Slightly lighter forest tone
          dividerColor: const Color(0xFF1F3329),
          hintColor: const Color(0xFF4B3A2B), // Earthy brown hint
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2E4E3F),
            secondary: Color(0xFF614D3B), // Warm brown accent
            tertiary: Color(0xFF8C6E54), // Lighter wood tone
            primaryContainer: Color(0xFF264033),
            secondaryContainer: Color(0xFF4B3A2B),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B1F16),
            foregroundColor: Color(0xFFD0D0D0),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF16281F),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

      case AppThemeMode.midNight:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF321246), // Deep purple
          scaffoldBackgroundColor:
              const Color(0xFF120520), // Very dark purple background
          cardColor:
              const Color(0xFF220A36), // Slightly lighter purple tone for cards
          dividerColor: const Color(0xFF321246),
          hintColor: const Color(0xFF808080), // Subtle gray hint
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF321246),
            secondary: Color(0xFF673AB7),
            tertiary: Color(0xFFD1C4E9),
            primaryContainer: Color(0xFF220A36),
            secondaryContainer: Color(0xFFBB86FC),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF120520),
            foregroundColor: Color(0xFFE6E6E6),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            color: const Color(0xFF220A36),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          extensions: [
            const CustomThemeExtension(
              fileCardBackground: Color(0xFF220A36),
              fileCardText: Color(0xFFE6E6E6),
              aiMessageBackground: Color(0xFF321246),
              aiMessageText: Color(0xFFD0D0D0),
              minimalFileCardBackground: Color(0xFF220A36),
              minimalFileCardText: Color(0xFFE6E6E6),
            ),
          ],
        );

      default:
        return _getLightTheme();
    }
  }

  static ThemeData _getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF6B8F71), // Soft sage/olive green
      scaffoldBackgroundColor: const Color(0xFFF5F2ED), // Warm off-white
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE0E0E0),
      hintColor: const Color(0xFF8C9A76), // Subtle greenish hint
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6B8F71), // Sage/Olive
        secondary: Color(0xFFB5A89E), // Warm neutral
        tertiary: Color(0xFFE9CFA3), // Light, warm golden
        surface: Color(0xFFFFFFFF),
        surfaceTint: Color(0xFF6B8F71), // Tint surfaces with sage
        primaryContainer: Color(0xFFC4D9C7), // Lighter sage for containers
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F2ED), // Same as scaffold
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
  }

  static ThemeData _getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF433E8A), // Deep indigo
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF0A0A0A), // Off-black for cards
      dividerColor: const Color(0xFF1F1F1F),
      hintColor: const Color(0xFF6F6BAE), // Indigo hint
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF433E8A),
        secondary: Color(0xFF6F6BAE),
        tertiary: Color(0xFFA29FDC),
        primaryContainer: Color(0xFF353165),
        secondaryContainer: Color(0xFF5C58A7),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Color(0xFFE6E6E6),
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF0A0A0A),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      extensions: [
        const CustomThemeExtension(
          fileCardBackground: Color(0xFF0A0A0A),
          fileCardText: Color(0xFFE6E6E6),
          aiMessageBackground: Color(0xFF321246),
          aiMessageText: Color(0xFFD0D0D0),
          minimalFileCardBackground: Color(0xFF0A0A0A),
          minimalFileCardText: Color(0xFFE6E6E6),
        ),
      ],
    );
  }
}
