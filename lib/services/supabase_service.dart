import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart' as app_models;
import '../models/user_preferences.dart';
import '../models/user_library.dart';
import '../models/user_ai_settings.dart';

class SupabaseService {
  final SupabaseClient _client;
  static const String _userProfilesTable = 'user_profiles';
  static const String _userPreferencesTable = 'user_preferences';
  static const String _userLibraryTable = 'user_library';
  static const String _userAiSettingsTable = 'user_ai_settings';

  SupabaseService(this._client);

  static Future<SupabaseService> initialize() async {
    await dotenv.load();
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    return SupabaseService(Supabase.instance.client);
  }

  // Authentication methods
  Future<app_models.User?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Create user profile
        await _client.from(_userProfilesTable).insert({
          'id': response.user!.id,
          'email': email,
          'username': username,
        });

        return app_models.User(
          id: response.user!.id,
          email: email,
          username: username,
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<app_models.User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userData = await getUserData();
        return userData;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // User data methods
  Future<app_models.User?> getUserData() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final profile = await _client
          .from(_userProfilesTable)
          .select()
          .eq('id', userId)
          .single();

      final preferences = await _client
          .from(_userPreferencesTable)
          .select()
          .eq('user_id', userId)
          .single();

      final library = await _client
          .from(_userLibraryTable)
          .select()
          .eq('user_id', userId)
          .single();

      final aiSettings = await _client
          .from(_userAiSettingsTable)
          .select()
          .eq('user_id', userId)
          .single();

      return app_models.User(
        id: profile['id'],
        email: profile['email'],
        username: profile['username'],
        preferences: UserPreferences.fromJson(preferences),
        library: UserLibrary.fromJson(library),
        aiSettings: UserAISettings.fromJson(aiSettings),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Update methods
  Future<void> updatePreferences(UserPreferences preferences) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from(_userPreferencesTable).upsert({
      'user_id': userId,
      ...preferences.toJson(),
    });
  }

  Future<void> updateLibrary(UserLibrary library) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from(_userLibraryTable).upsert({
      'user_id': userId,
      ...library.toJson(),
    });
  }

  Future<void> updateAiSettings(UserAISettings settings) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from(_userAiSettingsTable).upsert({
      'user_id': userId,
      ...settings.toJson(),
    });
  }

  // Sync methods
  Stream<app_models.User> syncUserData() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _client
        .from(_userProfilesTable)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((event) async {
          final userData = await getUserData();
          return userData!;
        });
  }
}
