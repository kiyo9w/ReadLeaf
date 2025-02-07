import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:read_leaf/models/user_preferences.dart';
import 'package:read_leaf/services/sync/sync_manager.dart';
import 'package:read_leaf/services/sync/sync_types.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';

@lazySingleton
class UserPreferencesService {
  static const String _boxName = 'user_preferences';
  late Box<Map> _box;
  final SyncManager _syncManager;
  final _uuid = const Uuid();
  final _log = Logger('UserPreferencesService');

  UserPreferencesService(this._syncManager);

  Future<void> init() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
    } catch (e) {
      // If box is corrupted, delete and recreate
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<Map>(_boxName);
    }
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    // Save locally
    await _box.put('preferences', preferences.toJson());

    // Queue for sync
    final task = SyncTask(
      id: _uuid.v4(),
      type: SyncTaskType.preferences,
      data: preferences.toJson(),
      timestamp: DateTime.now(),
      priority: SyncPriority.high,
    );

    await _syncManager.addTask(task);
  }

  UserPreferences getPreferences() {
    final data = _box.get('preferences');
    if (data != null) {
      return UserPreferences.fromJson(Map<String, dynamic>.from(data as Map));
    }
    return const UserPreferences();
  }

  Future<void> updateFromServer(Map<String, dynamic> serverData) async {
    final serverPrefs = UserPreferences.fromJson(serverData);
    final localPrefs = getPreferences();

    // Simple merge strategy: Take server values for all fields except customSettings
    final mergedPrefs = serverPrefs.copyWith(
      customSettings: {
        ...localPrefs.customSettings,
        ...serverPrefs.customSettings,
      },
    );

    await _box.put('preferences', mergedPrefs.toJson());
  }

  Future<void> clear() async {
    try {
      await _box.clear();
      _log.info('Cleared all user preferences');
    } catch (e) {
      _log.severe('Error clearing user preferences: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _box.close();
  }
}
