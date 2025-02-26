import 'package:flutter/material.dart';

/// Model representing a single page of content in an EPUB book
class EpubPageContent {
  final String content;
  final int chapterIndex;
  final int pageNumberInChapter;
  final String chapterTitle;
  final int wordCount;
  final int absolutePageNumber;

  const EpubPageContent({
    required this.content,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    required this.chapterTitle,
    this.wordCount = 0,
    this.absolutePageNumber = 0,
  });

  /// Create from a map (for deserialization from isolate)
  factory EpubPageContent.fromMap(Map<String, dynamic> map) {
    return EpubPageContent(
      content: map['content'] as String,
      chapterIndex: map['chapterIndex'] as int,
      pageNumberInChapter: map['pageNumberInChapter'] as int,
      chapterTitle: map['chapterTitle'] as String,
      wordCount: map['wordCount'] as int? ?? 0,
      absolutePageNumber: map['absolutePageNumber'] as int? ?? 0,
    );
  }

  /// Convert to a map (for serialization to isolate)
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'chapterIndex': chapterIndex,
      'pageNumberInChapter': pageNumberInChapter,
      'chapterTitle': chapterTitle,
      'wordCount': wordCount,
      'absolutePageNumber': absolutePageNumber,
    };
  }

  /// Create a copy with some changes
  EpubPageContent copyWith({
    String? content,
    int? chapterIndex,
    int? pageNumberInChapter,
    String? chapterTitle,
    int? wordCount,
    int? absolutePageNumber,
  }) {
    return EpubPageContent(
      content: content ?? this.content,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageNumberInChapter: pageNumberInChapter ?? this.pageNumberInChapter,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      wordCount: wordCount ?? this.wordCount,
      absolutePageNumber: absolutePageNumber ?? this.absolutePageNumber,
    );
  }
}

/// Model representing metadata about a chapter's pagination
class ChapterPaginationInfo {
  final int chapterIndex;
  final String chapterTitle;
  final int pageCount;
  final int wordCount;
  final int startAbsolutePageNumber;
  final int endAbsolutePageNumber;

  const ChapterPaginationInfo({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.pageCount,
    required this.wordCount,
    required this.startAbsolutePageNumber,
    required this.endAbsolutePageNumber,
  });

  factory ChapterPaginationInfo.fromMap(Map<String, dynamic> map) {
    return ChapterPaginationInfo(
      chapterIndex: map['chapterIndex'] as int,
      chapterTitle: map['chapterTitle'] as String,
      pageCount: map['pageCount'] as int,
      wordCount: map['wordCount'] as int,
      startAbsolutePageNumber: map['startAbsolutePageNumber'] as int,
      endAbsolutePageNumber: map['endAbsolutePageNumber'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'pageCount': pageCount,
      'wordCount': wordCount,
      'startAbsolutePageNumber': startAbsolutePageNumber,
      'endAbsolutePageNumber': endAbsolutePageNumber,
    };
  }
}

/// Model representing pagination metrics for the book
class EpubPaginationMetrics {
  final int totalPages;
  final int totalWords;
  final double fontSize;
  final double viewportWidth;
  final double viewportHeight;
  final List<ChapterPaginationInfo> chapterInfo;
  final DateTime calculatedAt;

  const EpubPaginationMetrics({
    required this.totalPages,
    required this.totalWords,
    required this.fontSize,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.chapterInfo,
    required this.calculatedAt,
  });

  factory EpubPaginationMetrics.empty() {
    return EpubPaginationMetrics(
      totalPages: 0,
      totalWords: 0,
      fontSize: 23.0,
      viewportWidth: 0,
      viewportHeight: 0,
      chapterInfo: const [],
      calculatedAt: DateTime.now(),
    );
  }

  factory EpubPaginationMetrics.fromMap(Map<String, dynamic> map) {
    return EpubPaginationMetrics(
      totalPages: map['totalPages'] as int,
      totalWords: map['totalWords'] as int,
      fontSize: map['fontSize'] as double,
      viewportWidth: map['viewportWidth'] as double,
      viewportHeight: map['viewportHeight'] as double,
      chapterInfo: (map['chapterInfo'] as List)
          .map((info) => ChapterPaginationInfo.fromMap(info))
          .toList(),
      calculatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['calculatedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPages': totalPages,
      'totalWords': totalWords,
      'fontSize': fontSize,
      'viewportWidth': viewportWidth,
      'viewportHeight': viewportHeight,
      'chapterInfo': chapterInfo.map((info) => info.toMap()).toList(),
      'calculatedAt': calculatedAt.millisecondsSinceEpoch,
    };
  }

  /// Check if this pagination matches the current display settings
  bool matchesSettings({
    required double fontSize,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    // Allow small differences in viewport size
    const double tolerance = 5.0;

    return this.fontSize == fontSize &&
        (this.viewportWidth - viewportWidth).abs() < tolerance &&
        (this.viewportHeight - viewportHeight).abs() < tolerance;
  }
}
