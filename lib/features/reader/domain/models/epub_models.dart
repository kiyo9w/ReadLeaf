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

  /// The plain text content (for direct rendering if HTML fails)
  final String plainText;

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
    String? plainText,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    required this.chapterTitle,
    required this.absolutePageNumber,
  }) : this.plainText = plainText ?? _stripHtmlTags(content);

  // Static helper to strip HTML tags
  static String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
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
  /// The text content
  final String text;

  /// The HTML tag (p, h1, h2, etc.)
  final String tag;

  ContentBlock({
    required this.text,
    required this.tag,
  });
}
