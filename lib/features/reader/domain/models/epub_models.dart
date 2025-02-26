import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';

/// Result object for EPUB processing operations
class EpubProcessingResult {
  /// The loaded EPUB book
  final EpubBook book;

  /// Flattened list of all chapters
  final List<EpubChapter> chapters;

  /// Map of chapter index to HTML content
  final Map<int, String> chapterContents;

  /// Map of configuration key to calculated pages
  /// Key format: '$chapterIndex_$viewportWidth_$viewportHeight_$fontSize'
  final Map<String, List<EpubPage>> pages;

  EpubProcessingResult({
    required this.book,
    required this.chapters,
    required this.chapterContents,
    required this.pages,
  });
}

/// Represents a single page of EPUB content
class EpubPage {
  /// The HTML content of the page
  final String content;

  /// The index of the chapter this page belongs to
  final int chapterIndex;

  /// The page number within the chapter (1-based)
  final int pageNumberInChapter;

  /// The title of the chapter
  final String chapterTitle;

  /// The absolute page number in the book (0-based)
  /// May be updated later when pagination is complete
  int absolutePageNumber;

  EpubPage({
    required this.content,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    required this.chapterTitle,
    required this.absolutePageNumber,
  });
}

/// Represents parsed HTML content blocks with styles
class ParsedContent {
  /// The list of content blocks
  final List<ContentBlock> blocks;

  /// Map of tag names to text styles
  final Map<String, TextStyle> styles;

  ParsedContent({
    required this.blocks,
    required this.styles,
  });
}

/// Represents a block of content (paragraph, header, etc.)
class ContentBlock {
  /// The styled text span
  final TextSpan textSpan;

  /// The raw HTML content
  final String rawHtml;

  /// Additional style information
  final Map<String, String> styles;

  ContentBlock({
    required this.textSpan,
    required this.rawHtml,
    required this.styles,
  });
}
