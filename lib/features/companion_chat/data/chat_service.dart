import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/features/companion_chat/domain/models/chat_message.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:read_leaf/features/settings/data/sync/sync_manager.dart';
import 'package:read_leaf/features/settings/data/sync/sync_types.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';

class ChatService {
  static const String _boxPrefix = 'character_chat_';
  static const int _maxMessagesPerCharacter = 200;
  static const int _batchSize = 50;
  final Map<String, Box<ChatMessage>> _boxes = {};
  final SyncManager _syncManager;
  final _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _pendingSync = {};
  Timer? _syncTimer;
  final _log = Logger('ChatService');
  final Map<String, List<ChatMessage>> _messageCache = {};

  ChatService(this._syncManager) {
    // Start periodic sync every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _queueMessagesForSync();
    });
  }

  // Generate a box name for a character
  String _getBoxName(String characterName) {
    final bytes = utf8.encode(characterName);
    final hash = sha256.convert(bytes);
    final boxName = '$_boxPrefix${hash.toString().substring(0, 20)}';
    print('Generated box name for character "$characterName": $boxName');
    return boxName;
  }

  Future<void> init() async {
    _log.info('Initializing ChatService');
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }

    // Close any existing boxes to ensure clean state
    await dispose();
  }

  Future<Box<ChatMessage>> _getBoxForCharacter(String characterName) async {
    try {
      _log.info('Getting box for character: $characterName');
      if (_boxes.containsKey(characterName)) {
        _log.info('Found existing box for $characterName');
        return _boxes[characterName]!;
      }

      final box = await Hive.openBox<ChatMessage>('chat_$characterName');
      _boxes[characterName] = box;
      _log.info('Box is open, message count: ${box.length}');
      return box;
    } catch (e) {
      _log.severe('Error opening box for character $characterName: $e');
      rethrow;
    }
  }

  Future<void> _syncPendingMessages() async {
    if (!_syncManager.isAuthenticated) {
      _log.info('Skipping sync - user not authenticated');
      return;
    }

    try {
      for (var entry in _pendingSync.entries) {
        if (entry.value.isEmpty) continue;

        final messages = entry.value.take(_batchSize).toList();
        final messageData = messages
            .map((msg) => {
                  'text': msg.text,
                  'is_user': msg.isUser,
                  'timestamp': msg.timestamp.toIso8601String(),
                  'character_name': msg.characterName,
                  'book_id': msg.bookId,
                  'avatar_image_path': msg.avatarImagePath,
                  'sync_version': 1,
                  'sync_status': 'pending',
                })
            .toList();

        try {
          await _syncManager.syncChatHistory(entry.key, messageData);
          entry.value.removeRange(0, messages.length);
          _log.info(
              'Successfully synced ${messages.length} messages for ${entry.key}');
        } catch (e) {
          _log.severe('Error syncing messages for ${entry.key}: $e');
          // Keep messages in pending queue for retry
        }
      }
    } catch (e) {
      _log.severe('Error in _syncPendingMessages: $e');
    }
  }

  Future<void> addMessage(ChatMessage message) async {
    if (message.characterName == null) {
      _log.warning('Character name is required for chat messages');
      throw Exception('Character name is required for chat messages');
    }

    try {
      final box = await _getBoxForCharacter(message.characterName!);

      // Add message with sync status
      final messageToAdd = message.copyWith(isSynced: false);
      await box.add(messageToAdd);
      _log.info('Added message for character: ${message.characterName}');

      // Queue message for sync if online
      if (_syncManager.isAuthenticated) {
        final task = SyncTask(
          id: _uuid.v4(),
          type: SyncTaskType.chatHistory,
          data: {
            'character_name': message.characterName,
            'messages': [
              {
                'text': message.text,
                'is_user': message.isUser,
                'timestamp': message.timestamp.toIso8601String(),
                'book_id': message.bookId,
                'avatar_image_path': message.avatarImagePath,
              }
            ],
          },
          timestamp: DateTime.now(),
          priority: SyncPriority.normal,
        );

        await _syncManager.addTask(task);
        _log.info('Created sync task for message');
      }

      // Clean up old messages if needed
      await _cleanupOldMessages(message.characterName!);
    } catch (e) {
      _log.severe('Error adding message: $e');
      rethrow;
    }
  }

  Future<void> _createSyncTask(String characterName) async {
    try {
      final messages = _pendingSync[characterName] ?? [];
      if (messages.isEmpty) return;

      _log.info(
          'Creating sync task for ${messages.length} messages from $characterName');

      final messageData = messages
          .map((msg) => {
                'text': msg.text,
                'is_user': msg.isUser,
                'timestamp': msg.timestamp.toIso8601String(),
                'character_name': msg.characterName,
                'book_id': msg.bookId,
                'avatar_image_path': msg.avatarImagePath,
              })
          .toList();

      await _syncManager.syncChatHistory(characterName, messageData);
      _pendingSync[characterName]?.clear();
    } catch (e) {
      _log.severe('Error creating sync task: $e');
    }
  }

  Future<void> _cleanupOldMessages(String characterName) async {
    try {
      final box = await _getBoxForCharacter(characterName);
      if (box.length > _maxMessagesPerCharacter) {
        _log.info('Cleaning up old messages for $characterName');
        final messagesToDelete = box.length - _maxMessagesPerCharacter;
        for (var i = 0; i < messagesToDelete; i++) {
          await box.deleteAt(0); // Delete oldest messages
        }
        _log.info('Deleted $messagesToDelete old messages');
      }
    } catch (e) {
      _log.severe('Error cleaning up old messages: $e');
    }
  }

  Future<void> updateFromServer(
      String characterName, List<Map<String, dynamic>> serverMessages) async {
    try {
      _log.info('Updating messages from server for $characterName');
      final box = await _getBoxForCharacter(characterName);

      // Get current local messages
      final localMessages = box.values.toList();
      _log.info('Found ${localMessages.length} local messages');

      // Create a map of existing messages by timestamp for quick lookup
      final existingMessageMap = {
        for (var msg in localMessages) msg.timestamp.toIso8601String(): msg
      };

      // Convert server messages to ChatMessage objects
      final serverChatMessages = serverMessages
          .map((data) {
            try {
              final timestamp = DateTime.parse(data['timestamp']);
              return ChatMessage(
                text: data['text'] as String,
                isUser: data['is_user'] as bool,
                timestamp: timestamp,
                characterName: data['character_name'] as String,
                bookId: data['book_id'] as String?,
                avatarImagePath: data['avatar_image_path'] as String?,
                isSynced: true,
                lastSyncedAt: DateTime.now(),
              );
            } catch (e) {
              _log.warning('Error converting server message: $e');
              _log.warning('Message data: $data');
              return null;
            }
          })
          .whereType<ChatMessage>()
          .toList();

      _log.info('Converted ${serverChatMessages.length} server messages');

      // Add or update messages from server
      for (var serverMsg in serverChatMessages) {
        final existingMsg =
            existingMessageMap[serverMsg.timestamp.toIso8601String()];
        if (existingMsg == null) {
          // Message doesn't exist locally, add it
          await box.add(serverMsg);
          _log.fine('Added new message from server: ${serverMsg.text}');
        } else if (!existingMsg.isSynced ||
            existingMsg.text != serverMsg.text ||
            existingMsg.isUser != serverMsg.isUser) {
          // Message exists but needs update
          final index = localMessages.indexOf(existingMsg);
          await box.putAt(index, serverMsg);
          _log.fine('Updated existing message from server: ${serverMsg.text}');
        }
      }

      _log.info('Successfully updated messages from server for $characterName');
    } catch (e, stackTrace) {
      _log.severe('Error updating messages from server for $characterName', e,
          stackTrace);
      rethrow;
    }
  }

  // Get all messages for a character
  Future<List<ChatMessage>> getCharacterMessages(String characterName) async {
    try {
      _log.info('Getting messages for character: $characterName');
      final box = await _getBoxForCharacter(characterName);

      final messages = box.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // If this is the first conversation, add the greeting message
      if (messages.isEmpty) {
        final aiCharacterService = GetIt.I<AiCharacterService>();
        final character = aiCharacterService.getSelectedCharacter();
        if (character != null &&
            character.name == characterName &&
            character.greetingMessage.isNotEmpty) {
          final greetingMessage = ChatMessage(
            text: character.greetingMessage,
            isUser: false,
            timestamp: DateTime.now(),
            characterName: characterName,
            bookId: null,
            avatarImagePath: character.avatarImagePath,
          );
          await addMessage(greetingMessage);
          messages.add(greetingMessage);
        }
      }

      _log.info('Retrieved ${messages.length} messages for $characterName');
      return messages;
    } catch (e) {
      _log.severe('Error getting messages for character $characterName: $e');
      rethrow;
    }
  }

  // Get the last N messages for context, regardless of book
  Future<List<ChatMessage>> getLastNMessages(String characterName,
      {int n = 10}) async {
    try {
      print('Getting last $n messages for character: $characterName');
      final box = await _getBoxForCharacter(characterName);
      final allMessages = box.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sort descending
      final messages = allMessages.take(n).toList()
        ..sort((a, b) =>
            a.timestamp.compareTo(b.timestamp)); // Sort ascending for display
      print('Retrieved ${messages.length} recent messages for $characterName');
      return messages;
    } catch (e) {
      print('Error getting last messages for character $characterName: $e');
      rethrow;
    }
  }

  Future<void> clearCharacterMessages(String characterName) async {
    try {
      _log.info('Clearing messages for character: $characterName');
      final box = await _getBoxForCharacter(characterName);
      await box.clear();

      // Clear cache
      _messageCache.remove(characterName);

      _log.info('Cleared messages successfully');

      // Queue empty sync to clear server messages
      final task = SyncTask(
        id: _uuid.v4(),
        type: SyncTaskType.chatHistory,
        data: {
          'character_name': characterName,
          'messages': [],
        },
        timestamp: DateTime.now(),
        priority: SyncPriority.high,
      );
      await _syncManager.addTask(task);
    } catch (e) {
      _log.severe('Error clearing messages: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _log.info('Disposing ChatService');
      // Clear cache
      _messageCache.clear();

      // Sync any pending messages before disposing
      await _syncPendingMessages();

      _syncTimer?.cancel();
      print('Disposing ChatService, closing all boxes');
      for (var entry in _boxes.entries) {
        print('Closing box for character: ${entry.key}');
        await entry.value.close();
      }
      _boxes.clear();
      _pendingSync.clear();
      print('All boxes closed');
    } catch (e) {
      print('Error disposing chat service: $e');
      rethrow;
    }
  }

  // Debug method to list all open boxes
  Future<void> debugPrintBoxes() async {
    print('\n=== DEBUG: Open Chat Boxes ===');
    for (var entry in _boxes.entries) {
      final box = entry.value;
      print('Character: ${entry.key}');
      print('Box name: ${box.name}');
      print('Message count: ${box.length}');
      print('Is open: ${box.isOpen}');
      print('---');
    }
    print('============================\n');
  }

  Future<void> retryFailedSync() async {
    await _syncPendingMessages();
  }

  // Force sync method for debug purposes
  Future<void> forceSync() async {
    _log.info('Force sync requested');
    try {
      // Check authentication first
      if (!_syncManager.isAuthenticated) {
        _log.warning('Cannot sync - user not authenticated');
        throw Exception('User not authenticated');
      }

      // Cancel any existing sync timer
      _syncTimer?.cancel();

      // Queue all messages for sync
      await _queueMessagesForSync();

      // Process pending tasks immediately
      await _syncManager.processPendingTasks();

      // Restart periodic sync timer
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _queueMessagesForSync();
      });

      _log.info('Force sync completed successfully');
    } catch (e) {
      _log.severe('Force sync failed: $e');
      rethrow;
    }
  }

  Future<void> _queueMessagesForSync() async {
    if (!_syncManager.isAuthenticated) {
      _log.info('Skipping sync - user not authenticated');
      return;
    }

    try {
      for (final characterName in _boxes.keys) {
        final box = _boxes[characterName];
        if (box == null) continue;

        // Get only unsynced messages
        final messages = box.values.where((msg) => !msg.isSynced).toList();
        if (messages.isEmpty) {
          _log.info('No unsynced messages for $characterName');
          continue;
        }

        _log.info(
            'Found ${messages.length} unsynced messages for $characterName');

        // Create sync task for this batch of messages
        final task = SyncTask(
          id: _uuid.v4(),
          type: SyncTaskType.chatHistory,
          data: {
            'character_name': characterName,
            'messages': messages
                .map((msg) => {
                      'text': msg.text,
                      'is_user': msg.isUser,
                      'timestamp': msg.timestamp.toIso8601String(),
                      'book_id': msg.bookId,
                      'avatar_image_path': msg.avatarImagePath,
                    })
                .toList(),
          },
          timestamp: DateTime.now(),
          priority: SyncPriority.normal,
        );

        await _syncManager.addTask(task);
        _log.info(
            'Created sync task for ${messages.length} messages from $characterName');
      }
    } catch (e) {
      _log.severe('Error queueing messages for sync: $e');
      rethrow;
    }
  }

  /// Clears all local chat data and optionally syncs the cleared state to server
  Future<void> clearAllData({bool syncToServer = true}) async {
    try {
      _log.info('Clearing all chat data');

      final chatBoxNames = Hive.lazyBox<ChatMessage>('chat_boxes')
          .keys
          .where((name) => name.toString().startsWith('chat_'))
          .toList();

      // Iterate over each chat box on disk, clear and delete it.
      for (final boxName in chatBoxNames) {
        // Open the box (in case it is not already open)
        final box = await Hive.openBox<ChatMessage>(boxName);
        await box.clear();
        await box.close();
        await Hive.deleteBoxFromDisk(boxName);
        _log.info('Cleared and deleted box: $boxName');
      }
      _boxes.clear();
      _pendingSync.clear();

      // if (syncToServer && _syncManager.isAuthenticated) {
      //   // Create a sync task to clear server data
      //   final task = SyncTask(
      //     id: _uuid.v4(),
      //     type: SyncTaskType.chatHistory,
      //     data: {
      //       'clear_all': true,
      //       'timestamp': DateTime.now().toIso8601String(),
      //     },
      //     timestamp: DateTime.now(),
      //     priority: SyncPriority.high,
      //   );
      //   await _syncManager.addTask(task);
      // }

      _log.info('Successfully cleared all chat data');
    } catch (e) {
      _log.severe('Error clearing chat data: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsSynced(
      String characterName, List<DateTime> timestamps) async {
    try {
      final box = await _getBoxForCharacter(characterName);
      final messages = box.values.toList();

      for (var timestamp in timestamps) {
        final index = messages.indexWhere((msg) => msg.timestamp == timestamp);
        if (index != -1) {
          final message = messages[index];
          await box.putAt(
              index,
              message.copyWith(
                isSynced: true,
                lastSyncedAt: DateTime.now(),
              ));
        }
      }
      _log.info(
          'Marked ${timestamps.length} messages as synced for $characterName');
    } catch (e) {
      _log.severe('Error marking messages as synced: $e');
    }
  }
}
