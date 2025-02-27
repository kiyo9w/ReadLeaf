import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _showLoadingScreen = true;
  bool _remindersEnabled = true;

  bool get showLoadingScreen => _showLoadingScreen;
  bool get remindersEnabled => _remindersEnabled;

  // Initialize settings
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load reader loading screen preference (default to true if not set)
    _showLoadingScreen = prefs.getBool('show_loading_screen') ?? true;

    // Load reading reminders preference (default to true if not set)
    _remindersEnabled = prefs.getBool('reminders_enabled') ?? true;

    notifyListeners();
  }

  // Toggle loading screen setting
  Future<void> toggleLoadingScreen(bool value) async {
    _showLoadingScreen = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_loading_screen', value);
    notifyListeners();
  }

  // Toggle reading reminders
  Future<void> toggleReminders(bool value) async {
    _remindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', value);
    notifyListeners();
  }
}
