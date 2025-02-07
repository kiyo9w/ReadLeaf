import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'sync_types.dart';
import 'sync_queue.dart';
import 'offline_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';
import '../chat_service.dart';
import '../ai_character_service.dart';

class SyncManager {
  final _log = Logger('SyncManager');
  final SupabaseClient _supabase;
  final SyncQueue _mainQueue;
  final OfflineManager _offlineManager;
  final _uuid = const Uuid();
  Timer? _syncTimer;
  bool _initialized = false;

  // Add status stream
  final _statusController = BehaviorSubject<SyncStatus>();
  Stream<SyncStatus> get status => _statusController.stream;

  // Add pending task count
  int get pendingTaskCount => _mainQueue.length;

  // Add authentication check
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  SyncManager(this._supabase)
      : _mainQueue = SyncQueue(),
        _offlineManager = OfflineManager(SyncQueue()) {
    // Listen to queue status
    _mainQueue.status.listen((status) {
      _statusController.add(status);
      _log.info('Sync status changed to: $status');
    });

    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _log.info('User signed in, processing pending tasks');
        processPendingTasks();
      }
    });
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _log.info('Initializing SyncManager');
    // Start periodic sync
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _log.info('Starting periodic sync');
        processPendingTasks();
      },
    );

    // Listen to auth state changes and sync from server when user logs in
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        _log.info('User signed in, syncing data from server');
        await syncFromServer();
      }
    });

    _initialized = true;
    _log.info('SyncManager initialized successfully');
  }

  Future<void> addTask(SyncTask task) async {
    _log.fine('Adding sync task: ${task.type} (${task.id})');
    if (!isAuthenticated) {
      _log.info('User not authenticated, queueing task for later');
      await _offlineManager.queueOfflineChanges(task);
      return;
    }

    if (_offlineManager.isOnline) {
      await _mainQueue.addTask(task);
      _log.info('Task added to main queue: ${task.type}');
      // Process immediately if it's a high priority task
      if (task.priority == SyncPriority.high ||
          task.priority == SyncPriority.immediate) {
        await processPendingTasks();
      }
    } else {
      await _offlineManager.queueOfflineChanges(task);
      _log.info('Task queued for offline sync: ${task.type}');
    }
  }

  Future<void> processPendingTasks() async {
    if (!isAuthenticated) {
      _log.warning('Cannot process tasks: User not authenticated');
      _statusController.add(SyncStatus.failed);
      return;
    }

    if (!_offlineManager.isOnline) {
      _log.warning('Cannot process tasks: Device is offline');
      _statusController.add(SyncStatus.offline);
      return;
    }

    try {
      _log.info('Processing ${_mainQueue.length} pending tasks');
      _statusController.add(SyncStatus.syncing);

      final tasks = await _mainQueue.getTasks();
      if (tasks.isEmpty) {
        _log.info('No tasks to process');
        _statusController.add(SyncStatus.completed);
        return;
      }

      for (final task in tasks) {
        try {
          _log.info('Processing task: ${task.type} (${task.id})');
          await _processSyncTask(task);
          await _mainQueue.removeTask(task.id);
        } catch (e, stackTrace) {
          _log.severe('Error processing task ${task.id}', e, stackTrace);
          if (task.retryCount >= 3) {
            _log.warning('Task ${task.id} failed too many times, removing');
            await _mainQueue.removeTask(task.id);
          }
        }
      }

      _statusController.add(SyncStatus.completed);
    } catch (e, stackTrace) {
      _log.severe('Error during sync process', e, stackTrace);
      _statusController.add(SyncStatus.failed);
    }
  }

  Future<void> retryFailedTasks() async {
    await _mainQueue.retryFailedTasks();
  }

  // Preferences Sync
  Future<void> syncPreferences(Map<String, dynamic> preferences) async {
    final task = SyncTask(
      id: _uuid.v4(),
      type: 'preferences',
      data: preferences,
      timestamp: DateTime.now(),
      priority: SyncPriority.high,
    );

    if (_offlineManager.isOnline) {
      await _mainQueue.addTask(task);
    } else {
      await _offlineManager.queueOfflineChanges(task);
    }
  }

  // Reading Progress Sync
  Future<void> syncReadingProgress(
      String bookId, Map<String, dynamic> progress) async {
    final task = SyncTask(
      id: _uuid.v4(),
      type: 'reading_progress',
      data: {
        'book_id': bookId,
        ...progress,
      },
      timestamp: DateTime.now(),
      priority: SyncPriority.normal,
    );

    if (_offlineManager.isOnline) {
      await _mainQueue.addTask(task);
    } else {
      await _offlineManager.queueOfflineChanges(task);
    }
  }

  // Character Preferences Sync
  Future<void> syncCharacterPreferences(
      String characterName, Map<String, dynamic> preferences) async {
    final task = SyncTask(
      id: _uuid.v4(),
      type: 'character_preferences',
      data: {
        'character_name': characterName,
        ...preferences,
      },
      timestamp: DateTime.now(),
      priority: SyncPriority.normal,
    );

    if (_offlineManager.isOnline) {
      await _mainQueue.addTask(task);
    } else {
      await _offlineManager.queueOfflineChanges(task);
    }
  }

  // Chat History Sync
  Future<void> syncChatHistory(
      String characterName, List<Map<String, dynamic>> messages) async {
    final task = SyncTask(
      id: _uuid.v4(),
      type: 'chat_history',
      data: {
        'character_name': characterName,
        'messages': messages,
      },
      timestamp: DateTime.now(),
      priority: SyncPriority.low,
    );

    if (_offlineManager.isOnline) {
      await _mainQueue.addTask(task);
    } else {
      await _offlineManager.queueOfflineChanges(task);
    }
  }

  // Process sync tasks
  Future<void> _processSyncTask(SyncTask task) async {
    try {
      _log.info('Processing task: ${task.type} (${task.id})');
      switch (task.type) {
        case 'preferences':
          await _syncPreferencesToServer(task.data);
          break;
        case 'reading_progress':
          await _syncReadingProgressToServer(task.data);
          break;
        case 'character_preferences':
          await _syncCharacterPreferencesToServer(task.data);
          break;
        case 'chat_history':
          await _syncChatHistoryToServer(task.data);
          break;
        default:
          _log.severe('Unknown task type: ${task.type}');
          throw SyncError(
            message: 'Unknown sync task type: ${task.type}',
            code: 'unknown_task_type',
            task: task,
          );
      }
      _log.info('Task completed successfully: ${task.type} (${task.id})');
    } catch (e, stackTrace) {
      _log.severe('Failed to process task: ${task.type}', e, stackTrace);
      throw SyncError(
        message: 'Failed to process sync task: ${e.toString()}',
        code: 'task_processing_failed',
        originalError: e,
        task: task,
      );
    }
  }

  // Server sync implementations
  Future<void> _syncPreferencesToServer(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _log.severe('Cannot sync preferences: User not authenticated');
      throw Exception('User not authenticated');
    }

    _log.info('Syncing preferences to server for user: $userId');
    final payload = {
      'user_id': userId,
      ...data,
      'last_synced_at': DateTime.now().toIso8601String(),
    };

    final response =
        await _supabase.from('user_preferences').upsert(payload).select();
    _log.info('Preferences sync response: $response');
  }

  Future<void> _syncReadingProgressToServer(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _log.severe('Cannot sync reading progress: User not authenticated');
      throw Exception('User not authenticated');
    }

    _log.info('Syncing reading progress for book: ${data['book_id']}');
    final payload = {
      'user_id': userId,
      ...data,
      'last_synced_at': DateTime.now().toIso8601String(),
    };

    final response =
        await _supabase.from('reading_progress').upsert(payload).select();
    _log.info('Reading progress sync response: $response');
  }

  Future<void> _syncCharacterPreferencesToServer(
      Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _log.severe('Cannot sync character preferences: User not authenticated');
      throw Exception('User not authenticated');
    }

    _log.info('Syncing preferences for character: ${data['character_name']}');
    final payload = {
      'user_id': userId,
      ...data,
      'last_synced_at': DateTime.now().toIso8601String(),
    };

    final response =
        await _supabase.from('character_preferences').upsert(payload).select();
    _log.info('Character preferences sync response: $response');
  }

  Future<void> _syncChatHistoryToServer(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _log.severe('Cannot sync chat history: User not authenticated');
      throw Exception('User not authenticated');
    }

    _log.info('Processing chat history sync task');

    try {
      // Handle clear all request
      if (data['clear_all'] == true) {
        _log.info('Clearing all chat history from server');
        await _supabase.from('chat_history').delete().eq('user_id', userId);
        _log.info('Successfully cleared all chat history from server');
        return;
      }

      final characterName = data['character_name'];
      final messages = data['messages'] as List;
      _log.info('Syncing chat history for character: $characterName');
      _log.info('Received ${messages.length} messages to sync');

      try {
        // Get existing messages for this character
        final existingMessages = await _supabase
            .from('chat_history')
            .select()
            .eq('user_id', userId)
            .eq('character_name', characterName);

        _log.info(
            'Found ${existingMessages.length} existing messages in Supabase');

        // Create a map of existing messages by timestamp for deduplication
        final existingMessageMap = {
          for (var msg in existingMessages) msg['timestamp']: msg
        };

        // Format messages according to the table schema, skipping duplicates
        final List<Map<String, dynamic>> messagesToSync = [];
        final List<DateTime> syncedTimestamps = [];

        for (var m in messages) {
          final timestamp = m['timestamp'] is DateTime
              ? m['timestamp'].toIso8601String()
              : m['timestamp'];

          // Skip if message already exists
          if (existingMessageMap.containsKey(timestamp)) {
            syncedTimestamps.add(DateTime.parse(timestamp));
            continue;
          }

          messagesToSync.add({
            'id': _uuid.v4(),
            'user_id': userId,
            'character_name': characterName,
            'message_text': m['text'],
            'is_user': m['is_user'],
            'timestamp': timestamp,
            'book_id': m['book_id'],
            'avatar_image_path': m['avatar_image_path'],
            'sync_status': 'synced',
            'sync_version': 1,
            'last_synced_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        if (messagesToSync.isEmpty) {
          _log.info('No new messages to sync');
          return;
        }

        _log.info(
            'Preparing to sync ${messagesToSync.length} messages to Supabase');
        _log.info('Sample message payload: ${messagesToSync.first}');

        try {
          // First verify we're still authenticated
          if (_supabase.auth.currentUser == null) {
            throw Exception('Lost authentication during sync process');
          }

          final response = await _supabase
              .from('chat_history')
              .upsert(messagesToSync)
              .select();

          _log.info(
              'Successfully synced messages. Response length: ${response.length}');

          // Mark messages as synced in local storage
          if (syncedTimestamps.isNotEmpty) {
            final chatService = GetIt.instance<ChatService>();
            await chatService.markMessagesAsSynced(
                characterName, syncedTimestamps);
          }
        } catch (e) {
          _log.severe('Failed to upsert messages to Supabase: $e');
          rethrow;
        }
      } catch (e) {
        _log.severe('Error in _syncChatHistoryToServer: $e');
        rethrow;
      }
    } catch (e) {
      _log.severe('Error in _syncChatHistoryToServer: $e');
      rethrow;
    }
  }

  /// Syncs all data from server to local storage
  Future<void> syncFromServer() async {
    if (!isAuthenticated) {
      _log.warning('Cannot sync from server: User not authenticated');
      return;
    }

    try {
      _log.info('Starting sync from server');
      _statusController.add(SyncStatus.syncing);

      // Get user ID
      final userId = _supabase.auth.currentUser!.id;

      // Fetch chat history from server with proper ordering and filtering
      final chatHistory = await _supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: true)
          .limit(1000); // Increased limit to ensure we get all messages

      _log.info('Fetched ${chatHistory.length} messages from server');

      // Group messages by character
      final messagesByCharacter = <String, List<Map<String, dynamic>>>{};
      for (final message in chatHistory) {
        final characterName = message['character_name'] as String;
        messagesByCharacter.putIfAbsent(characterName, () => []).add({
          'text': message['message_text'],
          'is_user': message['is_user'],
          'timestamp': message['timestamp'],
          'character_name': message['character_name'],
          'book_id': message['book_id'],
          'avatar_image_path': message['avatar_image_path'],
        });
      }

      // Notify chat service to update local storage
      final chatService = GetIt.instance<ChatService>();
      for (final entry in messagesByCharacter.entries) {
        final characterName = entry.key;
        final messages = entry.value;
        _log.info(
            'Syncing ${messages.length} messages for character $characterName');
        await chatService.updateFromServer(characterName, messages);
      }

      // Fetch character preferences from server
      final characterPrefs = await _supabase
          .from('character_preferences')
          .select()
          .eq('user_id', userId);

      // Update character preferences in local storage
      final aiCharacterService = GetIt.instance<AiCharacterService>();
      for (final pref in characterPrefs) {
        await aiCharacterService.updatePreferenceFromServer(
          pref['character_name'],
          DateTime.parse(pref['last_used']),
          pref['custom_settings'] ?? {},
        );
      }

      _log.info('Server sync completed successfully');
      _statusController.add(SyncStatus.completed);
    } catch (e, stackTrace) {
      _log.severe('Error syncing from server', e, stackTrace);
      _statusController.add(SyncStatus.failed);
      rethrow;
    }
  }

  void dispose() {
    _log.info('Disposing SyncManager');
    _syncTimer?.cancel();
    _mainQueue.dispose();
    _offlineManager.dispose();
    _statusController.close();
  }
}
