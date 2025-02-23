import 'package:hive_flutter/hive_flutter.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class BookMetadataRepository {
  static const String _boxName = 'book_metadata';
  late Box<BookMetadata> _box;

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookMetadataAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TextHighlightAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AiConversationAdapter());
    }

    try {
      _box = await Hive.openBox<BookMetadata>(_boxName);
    } catch (e) {
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<BookMetadata>(_boxName);
    }
  }

  // Convert file path to a fixed-length key
  String _getKey(String filePath) {
    final bytes = utf8.encode(filePath);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32); // Use first 32 chars of hash
  }

  // Save metadata for a book
  Future<void> saveMetadata(BookMetadata metadata) async {
    final key = _getKey(metadata.filePath);
    await _box.put(key, metadata);
  }

  // Get metadata for a book
  BookMetadata? getMetadata(String filePath) {
    final key = _getKey(filePath);
    return _box.get(key);
  }

  // Update last opened page
  Future<void> updateLastOpenedPage(String filePath, int pageNumber) async {
    final key = _getKey(filePath);
    final metadata = _box.get(key);
    if (metadata != null) {
      final updatedMetadata = metadata.copyWith(
        lastOpenedPage: pageNumber,
        lastReadTime: DateTime.now(),
        readingProgress: pageNumber / metadata.totalPages,
      );
      await _box.put(key, updatedMetadata);
    }
  }

  // Add a highlight
  Future<void> addHighlight(String filePath, TextHighlight highlight) async {
    final key = _getKey(filePath);
    final metadata = _box.get(key);
    if (metadata != null) {
      final updatedHighlights = [...metadata.highlights, highlight];
      final updatedMetadata = metadata.copyWith(highlights: updatedHighlights);
      await _box.put(key, updatedMetadata);
    }
  }

  // Add an AI conversation
  Future<void> addAiConversation(
      String filePath, AiConversation conversation) async {
    final key = _getKey(filePath);
    final metadata = _box.get(key);
    if (metadata != null) {
      final updatedConversations = [...metadata.aiConversations, conversation];
      final updatedMetadata =
          metadata.copyWith(aiConversations: updatedConversations);
      await _box.put(key, updatedMetadata);
    }
  }

  // Toggle starred status
  Future<void> toggleStarred(String filePath) async {
    final key = _getKey(filePath);
    final metadata = _box.get(key);
    if (metadata != null) {
      final updatedMetadata = metadata.copyWith(isStarred: !metadata.isStarred);
      await _box.put(key, updatedMetadata);
    }
  }

  // Get all metadata
  List<BookMetadata> getAllMetadata() {
    return _box.values.toList();
  }

  // Delete metadata for a book
  Future<void> deleteMetadata(String filePath) async {
    final key = _getKey(filePath);
    await _box.delete(key);
  }

  // Close the box
  Future<void> close() async {
    await _box.close();
  }

  /// Clears all local book metadata
  Future<void> clear() async {
    try {
      await _box.clear();
      print('Cleared all local book metadata');
    } catch (e) {
      print('Error clearing book metadata: $e');
      rethrow;
    }
  }
}
