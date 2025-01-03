import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'book_metadata.g.dart';

@HiveType(typeId: 0)
class BookMetadata extends Equatable {
  @HiveField(0)
  final String filePath;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? author;

  @HiveField(3)
  final int lastOpenedPage;

  @HiveField(4)
  final int totalPages;

  @HiveField(5)
  final List<TextHighlight> highlights;

  @HiveField(6)
  final List<AiConversation> aiConversations;

  @HiveField(7)
  final bool isStarred;

  @HiveField(8)
  final DateTime lastReadTime;

  @HiveField(9)
  final double readingProgress; // 0.0 to 1.0

  const BookMetadata({
    required this.filePath,
    required this.title,
    this.author,
    this.lastOpenedPage = 1,
    required this.totalPages,
    this.highlights = const [],
    this.aiConversations = const [],
    this.isStarred = false,
    required this.lastReadTime,
    this.readingProgress = 0.0,
  });

  BookMetadata copyWith({
    String? filePath,
    String? title,
    String? author,
    int? lastOpenedPage,
    int? totalPages,
    List<TextHighlight>? highlights,
    List<AiConversation>? aiConversations,
    bool? isStarred,
    DateTime? lastReadTime,
    double? readingProgress,
  }) {
    return BookMetadata(
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      author: author ?? this.author,
      lastOpenedPage: lastOpenedPage ?? this.lastOpenedPage,
      totalPages: totalPages ?? this.totalPages,
      highlights: highlights ?? this.highlights,
      aiConversations: aiConversations ?? this.aiConversations,
      isStarred: isStarred ?? this.isStarred,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      readingProgress: readingProgress ?? this.readingProgress,
    );
  }

  @override
  List<Object?> get props => [
        filePath,
        title,
        author,
        lastOpenedPage,
        totalPages,
        highlights,
        aiConversations,
        isStarred,
        lastReadTime,
        readingProgress,
      ];
}

@HiveType(typeId: 1)
class TextHighlight extends Equatable {
  @HiveField(0)
  final String text;

  @HiveField(1)
  final int pageNumber;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final String? note;

  const TextHighlight({
    required this.text,
    required this.pageNumber,
    required this.createdAt,
    this.note,
  });

  @override
  List<Object?> get props => [text, pageNumber, createdAt, note];
}

@HiveType(typeId: 2)
class AiConversation extends Equatable {
  @HiveField(0)
  final String selectedText;

  @HiveField(1)
  final String aiResponse;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final int pageNumber;

  const AiConversation({
    required this.selectedText,
    required this.aiResponse,
    required this.timestamp,
    required this.pageNumber,
  });

  @override
  List<Object> get props => [selectedText, aiResponse, timestamp, pageNumber];
}
