import 'package:hive/hive.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ChatService {
  static const String _boxPrefix = 'chat_';
  final Map<String, Box<ChatMessage>> _boxes = {};

  // Generate a short, ASCII-safe identifier from a book ID (file path)
  String _getBoxName(String bookId) {
    final bytes = utf8.encode(bookId);
    final hash = sha256.convert(bytes);
    return '${_boxPrefix}${hash.toString().substring(0, 20)}'; // Use first 20 chars of hash
  }

  Future<void> init() async {
    // Adapter is now registered in main.dart
  }

  Future<Box<ChatMessage>> _getBoxForBook(String bookId) async {
    if (_boxes.containsKey(bookId)) {
      return _boxes[bookId]!;
    }

    try {
      final boxName = _getBoxName(bookId);
      final box = await Hive.openBox<ChatMessage>(boxName);
      _boxes[bookId] = box;
      return box;
    } catch (e) {
      print('Error opening box for book $bookId: $e');
      rethrow;
    }
  }

  Future<void> addMessage(String bookId, ChatMessage message) async {
    try {
      final box = await _getBoxForBook(bookId);
      await box.add(message);
    } catch (e) {
      print('Error adding message for book $bookId: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessages(String bookId) async {
    try {
      final box = await _getBoxForBook(bookId);
      return box.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print('Error getting messages for book $bookId: $e');
      rethrow;
    }
  }

  Future<void> clearMessages(String bookId) async {
    try {
      final box = await _getBoxForBook(bookId);
      await box.clear();
    } catch (e) {
      print('Error clearing messages for book $bookId: $e');
      rethrow;
    }
  }

  Future<void> clearAllMessages() async {
    try {
      for (var box in _boxes.values) {
        await box.clear();
      }
    } catch (e) {
      print('Error clearing all messages: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      for (var box in _boxes.values) {
        await box.close();
      }
      _boxes.clear();
    } catch (e) {
      print('Error disposing chat service: $e');
      rethrow;
    }
  }
}
