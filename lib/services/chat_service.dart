import 'package:hive/hive.dart';
import 'package:read_leaf/models/chat_message.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:read_leaf/services/sync/sync_manager.dart';
import 'package:read_leaf/services/sync/sync_types.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

@lazySingleton
class ChatService {
  static const String _boxPrefix = 'character_chat_';
  static const int _maxMessagesPerCharacter = 200;
  static const int _batchSize = 50;
  final Map<String, Box<ChatMessage>> _boxes = {};
  final SyncManager _syncManager;
  final _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _pendingSync = {};
  Timer? _syncTimer;

  ChatService(this._syncManager) {
    // Start periodic sync timer
    _syncTimer = Timer.periodic(
        const Duration(minutes: 5), (_) => _syncPendingMessages());
  }

  // Generate a box name for a character
  String _getBoxName(String characterName) {
    final bytes = utf8.encode(characterName);
    final hash = sha256.convert(bytes);
    final boxName = '${_boxPrefix}${hash.toString().substring(0, 20)}';
    print('Generated box name for character "$characterName": $boxName');
    return boxName;
  }

  Future<void> init() async {
    // Close any existing boxes to ensure clean state
    await dispose();
  }

  Future<Box<ChatMessage>> _getBoxForCharacter(String characterName) async {
    print('Getting box for character: $characterName');

    // Always get a fresh box to ensure we have the latest data
    if (_boxes.containsKey(characterName)) {
      print('Found existing box for $characterName');
      final box = _boxes[characterName]!;
      if (box.isOpen) {
        print('Box is open, message count: ${box.length}');
        return box;
      } else {
        print('Box was closed, reopening');
        await box.close();
        _boxes.remove(characterName);
      }
    }

    try {
      final boxName = _getBoxName(characterName);
      print('Opening box: $boxName');

      // Close existing box with same name if exists
      if (Hive.isBoxOpen(boxName)) {
        print('Box was already open, closing first');
        await Hive.box<ChatMessage>(boxName).close();
      }

      final box = await Hive.openBox<ChatMessage>(boxName);
      _boxes[characterName] = box;
      print('Opened box for $characterName, message count: ${box.length}');
      return box;
    } catch (e) {
      print('Error opening box for character $characterName: $e');
      rethrow;
    }
  }

  Future<void> _syncPendingMessages() async {
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
              })
          .toList();

      await _syncManager.syncChatHistory(entry.key, messageData);
      entry.value.removeRange(0, messages.length);
    }
  }

  Future<void> addMessage(ChatMessage message) async {
    if (message.characterName == null) {
      throw Exception('Character name is required for chat messages');
    }

    try {
      print('Adding message for character: ${message.characterName}');
      final box = await _getBoxForCharacter(message.characterName!);

      // Ensure we don't exceed max messages per character
      if (box.length >= _maxMessagesPerCharacter) {
        // Remove oldest messages to maintain limit
        final keys = box.keys.toList()
          ..sort(
              (a, b) => box.get(a)!.timestamp.compareTo(box.get(b)!.timestamp));
        final keysToDelete =
            keys.take(box.length - _maxMessagesPerCharacter + 1);
        await box.deleteAll(keysToDelete);
      }

      await box.add(message);
      print('Added message. New message count: ${box.length}');

      // Queue for sync
      _pendingSync.putIfAbsent(message.characterName!, () => []).add(message);
    } catch (e) {
      print('Error adding message for character ${message.characterName}: $e');
      rethrow;
    }
  }

  Future<void> updateFromServer(
      String characterName, List<Map<String, dynamic>> serverMessages) async {
    try {
      final box = await _getBoxForCharacter(characterName);

      // Convert server messages to ChatMessage objects
      final messages = serverMessages
          .map((data) => ChatMessage(
                text: data['text'],
                isUser: data['is_user'],
                timestamp: DateTime.parse(data['timestamp']),
                characterName: data['character_name'],
                bookId: data['book_id'],
              ))
          .toList();

      // Clear existing messages and add server messages
      await box.clear();
      await box.addAll(messages);

      print(
          'Updated ${messages.length} messages from server for $characterName');
    } catch (e) {
      print('Error updating messages from server for $characterName: $e');
      rethrow;
    }
  }

  // Get all messages for a character
  Future<List<ChatMessage>> getCharacterMessages(String characterName) async {
    try {
      print('Getting messages for character: $characterName');
      final box = await _getBoxForCharacter(characterName);
      final messages = box.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      print('Retrieved ${messages.length} messages for $characterName');
      return messages;
    } catch (e) {
      print('Error getting messages for character $characterName: $e');
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
      print('Clearing all messages for character: $characterName');
      final box = await _getBoxForCharacter(characterName);
      await box.clear();

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

      print('Cleared messages for $characterName');
    } catch (e) {
      print('Error clearing messages for character $characterName: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      // Sync any pending messages before disposing
      await _syncPendingMessages();

      _syncTimer?.cancel();
      print('Disposing ChatService, closing all boxes');
      for (var entry in _boxes.entries) {
        print('Closing box for character: ${entry.key}');
        await entry.value.close();
      }
      _boxes.clear();
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
}
