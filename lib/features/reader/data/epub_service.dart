import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:read_leaf/features/reader/domain/models/epub_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Service responsible for loading, parsing, and paginating EPUB files
class EpubService {
  // Cache for already processed books
  final Map<String, EpubProcessingResult> _processedBooks = {};

  // Additional caches for HTML parsing performance
  final Map<String, dom.Document> _parsedHtmlCache = {};

  // Performance tracking
  final Stopwatch _performanceStopwatch = Stopwatch();

  /// Load and process an EPUB file
  /// Returns a result with the parsed book and pages
  Future<EpubProcessingResult> loadEpub(String filePath) async {
    // Check cache first
    if (_processedBooks.containsKey(filePath)) {
      print('EPUB loaded from cache');
      return _processedBooks[filePath]!;
    }

    try {
      _performanceStopwatch.reset();
      _performanceStopwatch.start();

      // Load the EPUB file
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      // Measure just the file reading time
      final fileReadTime = _performanceStopwatch.elapsedMilliseconds;
      print('EPUB file read in ${fileReadTime}ms');
      _performanceStopwatch.reset();
      _performanceStopwatch.start();

      final epubBook = await EpubReader.readBook(bytes);

      // Measure just the EPUB parsing time
      final epubParseTime = _performanceStopwatch.elapsedMilliseconds;
      print('EPUB parsed in ${epubParseTime}ms');
      _performanceStopwatch.reset();
      _performanceStopwatch.start();

      // Parse the chapters
      final flatChapters = _flattenChapters(epubBook.Chapters ?? []);

      // Measure chapter flattening time
      final chapterFlattenTime = _performanceStopwatch.elapsedMilliseconds;
      print('Chapters flattened in ${chapterFlattenTime}ms');

      // Create the result
      final result = EpubProcessingResult(
        book: epubBook,
        chapters: flatChapters,
        chapterContents: {},
        pages: {},
      );

      // Store in cache
      _processedBooks[filePath] = result;

      print(
          'EPUB loaded in ${fileReadTime + epubParseTime + chapterFlattenTime}ms (total)');
      return result;
    } catch (e) {
      print('Error loading EPUB: $e');
      rethrow;
    }
  }

  /// Calculate pages for a chapter with specified dimensions and font size
  Future<List<EpubPage>> calculatePages({
    required EpubProcessingResult processingResult,
    required int chapterIndex,
    required double viewportWidth,
    required double viewportHeight,
    required double fontSize,
  }) async {
    // Check if we already calculated pages for this chapter and configuration
    final cacheKey =
        '${chapterIndex}_${viewportWidth}_${viewportHeight}_$fontSize';
    if (processingResult.pages.containsKey(cacheKey)) {
      return processingResult.pages[cacheKey]!;
    }

    try {
      _performanceStopwatch.reset();
      _performanceStopwatch.start();

      // Get or load chapter content
      final chapter = processingResult.chapters[chapterIndex];
      String content = await _getChapterContent(processingResult, chapterIndex);

      final contentLoadTime = _performanceStopwatch.elapsedMilliseconds;
      _performanceStopwatch.reset();
      _performanceStopwatch.start();

      // Create page calculator
      final calculator = EpubPageCalculator(
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        fontSize: fontSize,
      );

      // Calculate pages using the TextPainter-based approach
      final pages = await calculator.calculatePages(
        content,
        chapterIndex,
        chapter.Title ?? 'Chapter ${chapterIndex + 1}',
      );

      final paginationTime = _performanceStopwatch.elapsedMilliseconds;
      print(
          'Chapter $chapterIndex: content loaded in ${contentLoadTime}ms, paginated in ${paginationTime}ms (${pages.length} pages)');

      // Cache the result
      processingResult.pages[cacheKey] = pages;

      return pages;
    } catch (e) {
      print('Error calculating pages for chapter $chapterIndex: $e');
      return [
        EpubPage(
          content: '<p>Error loading chapter content: $e</p>',
          plainText: 'Error loading chapter content: $e',
          chapterIndex: chapterIndex,
          pageNumberInChapter: 1,
          chapterTitle: processingResult.chapters[chapterIndex].Title ??
              'Chapter ${chapterIndex + 1}',
          absolutePageNumber: 0,
        )
      ];
    }
  }

  /// Get the content of a chapter, loading if necessary
  Future<String> _getChapterContent(
    EpubProcessingResult processingResult,
    int chapterIndex,
  ) async {
    // Check cache first
    if (processingResult.chapterContents.containsKey(chapterIndex)) {
      return processingResult.chapterContents[chapterIndex]!;
    }

    final chapter = processingResult.chapters[chapterIndex];
    String content = chapter.HtmlContent ?? '';
    content = _cleanHtml(content);

    if (content.isEmpty) {
      content = '<p>Chapter content unavailable</p>';
    }

    // Cache the content
    processingResult.chapterContents[chapterIndex] = content;

    return content;
  }

  /// Clean and normalize HTML content - optimized version
  String _cleanHtml(String html) {
    if (html.isEmpty) return html;

    // First fix any HTML issues that might cause rendering problems
    String content = html;

    // NUCLEAR OPTION: Remove all headings from the HTML
    // This prevents duplicate headings completely - we'll add our own chapter title
    content = content.replaceAll(
        RegExp(r'<h[1-6][^>]*>.*?</h[1-6]>', dotAll: true), '');

    // Remove empty paragraphs that might create spacing
    content = content.replaceAll(
        RegExp(r'<p[^>]*>(\s|&nbsp;)*</p>', dotAll: true), '');

    // Preserve line breaks before converting to standardized form
    content = content.replaceAll('<br>', ''); // Remove br tags entirely
    content = content.replaceAll('<BR>', '');
    content = content.replaceAll('<br/>', '');

    // Remove excess whitespace but preserve intentional whitespace in pre tags
    // First protect <pre> tag content
    final preTagPattern = RegExp(r'<pre[^>]*>(.*?)</pre>', dotAll: true);
    final preTagMatches = preTagPattern.allMatches(content).toList();

    // Replace <pre> sections with placeholders
    for (int i = 0; i < preTagMatches.length; i++) {
      final match = preTagMatches[i];
      content = content.replaceRange(
          match.start, match.end, '___PRE_CONTENT_${i}___');
    }

    // Clean up whitespace in non-pre content
    content = content.replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();

    // Restore <pre> sections
    for (int i = 0; i < preTagMatches.length; i++) {
      final match = preTagMatches[i];
      final preContent = match.group(0) ?? '';
      content = content.replaceAll('___PRE_CONTENT_${i}___', preContent);
    }

    // Fix common issues in EPUB HTML (self-closing tags)
    content = content.replaceAllMapped(
      RegExp(r'<\s*([a-zA-Z][a-zA-Z0-9]*)[^>]*/\s*>'),
      (match) {
        final tag = match.group(1)?.toLowerCase() ?? '';
        // Don't expand truly self-closing tags
        if (tag == 'br' || tag == 'img' || tag == 'hr' || tag == 'input') {
          return match.group(0) ?? '';
        }
        return '<${match.group(1)}></${match.group(1)}>';
      },
    );

    return content;
  }

  /// Flatten chapters list including subchapters - optimized implementation
  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
    // Use a more efficient single-pass approach with a stack
    final result = <EpubChapter>[];
    final stack = <EpubChapter>[];

    // Start with all top-level chapters
    stack.addAll(chapters.reversed);

    // Process the stack
    while (stack.isNotEmpty) {
      final chapter = stack.removeLast();
      result.add(chapter);

      // Add subchapters in reverse order so they come out in correct order
      if (chapter.SubChapters?.isNotEmpty == true) {
        stack.addAll(chapter.SubChapters!.reversed);
      }
    }

    return result;
  }

  /// Parse the HTML content of a chapter to extract paragraphs and other elements
  List<dom.Element> parseChapterHtml(String htmlContent) {
    try {
      // Check for cached parse result
      if (_parsedHtmlCache.containsKey(htmlContent)) {
        return _parsedHtmlCache[htmlContent]!
            .getElementsByTagName('body')
            .first
            .children;
      }

      // More efficient body extraction using optimized regex
      final regExp = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      );

      final matches = regExp.firstMatch(htmlContent);
      final bodyContent =
          matches != null ? '<body>${matches.group(1)}</body>' : htmlContent;

      final document = parse(bodyContent);
      _parsedHtmlCache[htmlContent] = document;

      return _removeAllDiv(
          document.getElementsByTagName('body').first.children);
    } catch (e) {
      print('Error parsing chapter HTML: $e');
      return [];
    }
  }

  /// Process nested div elements to extract their children
  List<dom.Element> _removeAllDiv(List<dom.Element> elements) {
    final List<dom.Element> result = [];

    // Use a stack-based approach to avoid recursion
    final stack = <dom.Element>[];
    stack.addAll(elements.reversed);

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node.localName == 'div' && node.children.length > 1) {
        // Add children in reverse order so they come out in the right order
        stack.addAll(node.children.reversed);
      } else {
        result.add(node);
      }
    }

    return result;
  }

  /// Clear the cache for a specific file
  void clearCache(String filePath) {
    _processedBooks.remove(filePath);
  }

  /// Clear all cached data
  void clearAllCache() {
    _processedBooks.clear();
    _parsedHtmlCache.clear();
  }
}

/// Represents a content block extracted from HTML
class ContentBlock {
  final String text;
  final String tag; // p, h1, h2, etc.
  final bool isHtml;

  ContentBlock({required this.text, required this.tag, this.isHtml = false});
}

/// Helper class to store the result of paragraph splitting
class _ParagraphSplitResult {
  final String firstPart;
  final String secondPart;

  _ParagraphSplitResult(this.firstPart, this.secondPart);
}

/// A class to calculate and paginate EPUB content
class EpubPageCalculator {
  static const double DEFAULT_FONT_SIZE = 23.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 20.0;
  static const double PAGE_TOP_PADDING =
      35.0; // Added specific top padding for app bar
  static const double PAGE_HEIGHT_FRACTION =
      0.87; // Reduced from 0.9 to be even more conservative
  static const double SAFETY_MARGIN =
      0.0; // Dramatically increased from 50px to prevent overflow

  final double _viewportWidth;
  final double _viewportHeight;
  final double _fontSize;
  final double _effectiveViewportHeight;

  EpubPageCalculator({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = DEFAULT_FONT_SIZE,
  })  : _viewportWidth = viewportWidth - (PAGE_PADDING * 2),
        _viewportHeight = viewportHeight * PAGE_HEIGHT_FRACTION,
        _fontSize = fontSize,
        _effectiveViewportHeight = (viewportHeight * PAGE_HEIGHT_FRACTION) -
            (PAGE_PADDING + PAGE_TOP_PADDING) -
            SAFETY_MARGIN;

  // Calculate pages for a chapter using TextPainter for accurate text measurement
  Future<List<EpubPage>> calculatePages(
    String htmlContent,
    int chapterIndex,
    String chapterTitle,
  ) async {
    // Convert HTML to plain text
    final plainText = _stripHtmlTags(htmlContent);

    // Add chapter title at the beginning
    final textWithTitle = '$chapterTitle\n\n$plainText';

    // Create TextPainter with increased line height
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: textWithTitle,
        style: TextStyle(
          fontSize: _fontSize,
          height: LINE_HEIGHT_MULTIPLIER,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    // Lay out the text to get metrics
    textPainter.layout(maxWidth: _viewportWidth);

    // Get line metrics
    final List<ui.LineMetrics> lines = textPainter.computeLineMetrics();

    return _createPagesFromLines(
        textWithTitle, lines, textPainter, chapterIndex, chapterTitle);
  }

  // Create pages by finding where text should be split based on line metrics
  List<EpubPage> _createPagesFromLines(
    String text,
    List<ui.LineMetrics> lines,
    TextPainter textPainter,
    int chapterIndex,
    String chapterTitle,
  ) {
    final List<EpubPage> pages = [];

    // No lines, return empty page list
    if (lines.isEmpty) {
      return [
        EpubPage(
          content: '<p>$chapterTitle</p>',
          plainText: chapterTitle,
          chapterIndex: chapterIndex,
          pageNumberInChapter: 1,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0,
        )
      ];
    }

    // Use a smaller effective height for even more safety
    double currentPageBottom =
        _effectiveViewportHeight * 0.95; // Extra 5% reduction
    int currentPageStartIndex = 0;
    int pageNumber = 1;

    // Track lines per page for better debugging
    int linesOnCurrentPage = 0;
    final int maxLinesPerPage =
        (_effectiveViewportHeight / (_fontSize * LINE_HEIGHT_MULTIPLIER))
                .floor() -
            3; // -3 as extra safety buffer

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Calculate line position
      final top = line.baseline - line.ascent;
      final bottom = line.baseline + line.descent;

      // Check two conditions for page break:
      // 1. If the line would overflow the page height
      // 2. If we've reached our safety max line count
      if (bottom > currentPageBottom || linesOnCurrentPage >= maxLinesPerPage) {
        // Get position in text for page break
        final TextPosition position = textPainter.getPositionForOffset(
          Offset(line.left, top),
        );

        // Get the text for this page
        final pageEndIndex = position.offset;

        // Ensure we're actually making progress
        if (pageEndIndex <= currentPageStartIndex) {
          // Force include at least one line if we're stuck
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            final nextPosition = textPainter.getPositionForOffset(
              Offset(nextLine.left, nextLine.baseline - nextLine.ascent),
            );
            final pageText = text
                .substring(currentPageStartIndex, nextPosition.offset)
                .trim();
            pages.add(_createSimplePage(
                pageText, chapterIndex, pageNumber++, chapterTitle));
            currentPageStartIndex = nextPosition.offset;
            currentPageBottom = (nextLine.baseline - nextLine.ascent) +
                _effectiveViewportHeight * 0.95;
            linesOnCurrentPage = 0;
            continue;
          }
        }

        final pageText =
            text.substring(currentPageStartIndex, pageEndIndex).trim();

        // Create the page with simple HTML formatting
        pages.add(_createSimplePage(
            pageText, chapterIndex, pageNumber++, chapterTitle));

        // Start a new page
        currentPageStartIndex = pageEndIndex;
        currentPageBottom = top + (_effectiveViewportHeight * 0.95);
        linesOnCurrentPage = 0;
      } else {
        linesOnCurrentPage++;
      }
    }

    // Add the last page with any remaining content
    if (currentPageStartIndex < text.length) {
      final remainingText = text.substring(currentPageStartIndex).trim();

      if (remainingText.isNotEmpty) {
        pages.add(_createSimplePage(
            remainingText, chapterIndex, pageNumber, chapterTitle));
      }
    }

    return pages;
  }

  // Create a simple page with minimal formatting
  EpubPage _createSimplePage(
      String text, int chapterIndex, int pageNumber, String chapterTitle) {
    // Identify if this is the first page which would contain the title
    final bool isFirstPage = pageNumber == 1;

    // Format the content with minimal HTML - just basic paragraphs
    final paragraphs = text.split('\n\n');
    final formattedContent = StringBuffer();

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;

      // If this is the title on the first page, make it a heading
      if (isFirstPage && i == 0 && paragraph == chapterTitle) {
        formattedContent.write(
            '<h1 style="text-align: center; margin: 0.5em 0;">$paragraph</h1>');
      } else {
        formattedContent.write(
            '<p style="text-indent: 1.5em; margin: 0.3em 0;">$paragraph</p>');
      }
    }

    return EpubPage(
      content: formattedContent.toString(),
      plainText: text,
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumber,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0, // Will be set later
    );
  }

  // Strip HTML tags from text - simplified version
  String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';

    // Replace common HTML elements with appropriate whitespace
    String text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</?div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?h[1-6]>', caseSensitive: false), '\n\n');

    // Strip all remaining tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Normalize whitespace
    text = text
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Limit consecutive newlines
        .replaceAll(RegExp(r' {2,}'), ' ') // Limit consecutive spaces
        .trim();

    // Decode HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    return text;
  }
}

/// LRU Cache implementation for text width measurements
class LRUCache<K, V> {
  final int capacity;
  final Map<K, V> _cache = {};
  final List<K> _keys = [];

  LRUCache(this.capacity);

  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }

    // Move this key to the end (most recently used position)
    _keys.remove(key);
    _keys.add(key);

    return _cache[key];
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _keys.remove(key);
    } else if (_keys.length >= capacity) {
      // Remove the least recently used key
      final lruKey = _keys.removeAt(0);
      _cache.remove(lruKey);
    }

    _cache[key] = value;
    _keys.add(key);
  }

  void clear() {
    _cache.clear();
    _keys.clear();
  }

  // Get current cache size
  int get length => _cache.length;
}
