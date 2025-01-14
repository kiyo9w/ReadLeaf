import 'package:hive/hive.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ChatService {
  static const String _boxPrefix = 'character_chat_';
  final Map<String, Box<ChatMessage>> _boxes = {};

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

  Future<void> addMessage(ChatMessage message) async {
    if (message.characterName == null) {
      throw Exception('Character name is required for chat messages');
    }

    try {
      print('Adding message for character: ${message.characterName}');
      final box = await _getBoxForCharacter(message.characterName!);
      await box.add(message);
      print('Added message. New message count: ${box.length}');
    } catch (e) {
      print('Error adding message for character ${message.characterName}: $e');
      rethrow;
    }
  }

  // Get all messages for a character
  Future<List<ChatMessage>> getAllCharacterMessages(
      String characterName) async {
    try {
      print('Getting all messages for character: $characterName');
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

  // Get messages for a specific book and character
  Future<List<ChatMessage>> getBookMessages(
      String characterName, String bookId) async {
    try {
      print(
          'Getting book messages for character: $characterName, book: $bookId');
      final box = await _getBoxForCharacter(characterName);
      final messages = box.values.where((msg) => msg.bookId == bookId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      print('Retrieved ${messages.length} book messages for $characterName');
      return messages;
    } catch (e) {
      print('Error getting book messages for character $characterName: $e');
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
      print('Cleared messages for $characterName');
    } catch (e) {
      print('Error clearing messages for character $characterName: $e');
      rethrow;
    }
  }

  Future<void> clearBookMessages(String characterName, String bookId) async {
    try {
      print(
          'Clearing book messages for character: $characterName, book: $bookId');
      final box = await _getBoxForCharacter(characterName);
      final keysToDelete = box.values
          .where((msg) => msg.bookId == bookId)
          .map((msg) => msg.key)
          .toList();
      await box.deleteAll(keysToDelete);
      print(
          'Cleared ${keysToDelete.length} messages for $characterName in book $bookId');
    } catch (e) {
      print('Error clearing book messages for character $characterName: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
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
