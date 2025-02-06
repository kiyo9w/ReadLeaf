import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'sync_types.dart';
import 'sync_queue.dart';
import 'offline_manager.dart';
import 'package:rxdart/rxdart.dart';

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

    _log.info('Syncing chat history for character: ${data['character_name']}');
    _log.info('Received ${(data['messages'] as List).length} messages to sync');

    try {
      // Get existing messages for this character
      final existingMessages = await _supabase
          .from('chat_history')
          .select()
          .eq('user_id', userId)
          .eq('character_name', data['character_name'])
          .order('timestamp', ascending: false)
          .limit(200);

      _log.info(
          'Found ${existingMessages.length} existing messages in Supabase');

      // Format messages according to the table schema
      final List<Map<String, dynamic>> messages =
          (data['messages'] as List).map((m) {
        // Ensure timestamp is properly formatted
        final timestamp = m['timestamp'] is DateTime
            ? m['timestamp'].toIso8601String()
            : m['timestamp'];

        return {
          'id': _uuid.v4(), // Generate a unique ID for each message
          'user_id': userId,
          'character_name': data['character_name'],
          'message_text': m['text'], // Map 'text' to 'message_text'
          'is_user': m['is_user'],
          'timestamp': timestamp,
          'book_id': m['book_id'],
          'avatar_image_path': m['avatar_image_path'],
          'sync_status': 'synced',
          'sync_version': 1,
          'last_synced_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      _log.info('Preparing to sync ${messages.length} messages to Supabase');
      _log.info('Sample message payload: ${messages.first}');

      try {
        // First verify we're still authenticated
        if (_supabase.auth.currentUser == null) {
          throw Exception('Lost authentication during sync process');
        }

        final response =
            await _supabase.from('chat_history').upsert(messages).select();
        _log.info(
            'Successfully synced messages. Response length: ${response.length}');
      } catch (e) {
        _log.severe('Failed to upsert messages to Supabase: $e');
        rethrow;
      }
    } catch (e) {
      _log.severe('Error in _syncChatHistoryToServer: $e');
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
