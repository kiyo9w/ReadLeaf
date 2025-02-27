import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:read_leaf/features/reader/domain/models/epub_models.dart';

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

      // Calculate pages using the new TextPainter-based approach
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

    // Use more selective regex to avoid unnecessary replacements
    // Replace multiple whitespace with a single space only where needed
    String content = html.replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();

    // Fix common issues in EPUB HTML (self-closing tags)
    // Use a more optimized regex that only targets actual tags
    content = content.replaceAllMapped(
      RegExp(r'<\s*([a-zA-Z][a-zA-Z0-9]*)[^>]*/\s*>'),
      (match) => '<${match.group(1)}></${match.group(1)}>',
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

  ContentBlock({required this.text, required this.tag});
}

/// A class to calculate and paginate EPUB content
class EpubPageCalculator {
  static const double DEFAULT_FONT_SIZE = 23.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 20.0;
  static const double PAGE_HEIGHT_FRACTION = 0.92;
  static const double SAFETY_MARGIN = 15.0;
  static const double LINE_BREAK_FACTOR = 0.98;

  // Make these non-late final fields regular fields since we'll update them
  final double _viewportWidth;
  final double _viewportHeight;
  double _fontSize;
  final double _effectiveViewportHeight;
  // Debug flag for tracking page calculations
  final bool _debugMode = false;

  EpubPageCalculator({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = DEFAULT_FONT_SIZE,
  })  : _viewportWidth = viewportWidth - (PAGE_PADDING * 2),
        _viewportHeight = viewportHeight * PAGE_HEIGHT_FRACTION,
        _fontSize = fontSize,
        _effectiveViewportHeight = (viewportHeight * PAGE_HEIGHT_FRACTION) -
            (PAGE_PADDING * 2) -
            SAFETY_MARGIN;

  void updateFontSize(double newFontSize) {
    _fontSize = newFontSize;
  }

  // Calculate pages for a chapter with more accurate text measurement
  Future<List<EpubPage>> calculatePages(
    String htmlContent,
    int chapterIndex,
    String chapterTitle,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    // 1. Extract text content from HTML - keep it simple
    final plainText = _extractTextFromHtml(htmlContent);

    // 2. Create a TextStyle for measuring
    final TextStyle defaultStyle = TextStyle(
      fontSize: _fontSize,
      height: LINE_HEIGHT_MULTIPLIER,
    );

    // 3. Paginate using the direct method
    final List<EpubPage> pages = await _paginateText(plainText, defaultStyle,
        _viewportWidth, _effectiveViewportHeight, chapterIndex, chapterTitle);

    if (_debugMode) {
      print(
          'Chapter $chapterIndex paginated in ${stopwatch.elapsedMilliseconds}ms, created ${pages.length} pages');
    }

    return pages;
  }

  // Paginate text using the TextPainter approach
  Future<List<EpubPage>> _paginateText(
      String text,
      TextStyle style,
      double maxWidth,
      double maxHeight,
      int chapterIndex,
      String chapterTitle) async {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final List<EpubPage> pages = [];
    String remainingText = text;
    int pageNumber = 1;

    // If first portion of text appears to be a chapter heading, handle it specially
    if (chapterTitle.isNotEmpty &&
        remainingText.trim().startsWith(chapterTitle)) {
      // Create a special page just for the chapter title
      // This helps with chapter headings that need special formatting
      String chapterHeading =
          '<h1 style="text-align: center; font-weight: bold;">$chapterTitle</h1>';

      // Skip the title in the remaining text if it's at the beginning
      if (remainingText.trim().startsWith(chapterTitle)) {
        remainingText = remainingText.substring(chapterTitle.length).trim();
      }

      if (remainingText.isNotEmpty) {
        pages.add(EpubPage(
          content: chapterHeading,
          plainText: chapterTitle,
          chapterIndex: chapterIndex,
          pageNumberInChapter: pageNumber++,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0,
        ));
      }
    }

    while (remainingText.isNotEmpty) {
      textPainter.text = TextSpan(text: remainingText, style: style);
      textPainter.layout(maxWidth: maxWidth);

      // Use slightly less than the max height to ensure we don't overflow
      double adjustedMaxHeight = maxHeight * LINE_BREAK_FACTOR;
      int endIndex = textPainter
          .getPositionForOffset(Offset(maxWidth, adjustedMaxHeight))
          .offset;

      // Handle edge cases
      if (endIndex <= 0 || endIndex >= remainingText.length) {
        // We can either fit nothing or everything
        final pageText = remainingText;
        final htmlContent = _formatTextWithStyles(pageText);

        pages.add(EpubPage(
          content: htmlContent,
          plainText: pageText,
      chapterIndex: chapterIndex,
          pageNumberInChapter: pageNumber++,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0,
    ));
        break;
      }

      // Find optimal breaking point - preferring sentence endings
      int breakIndex = _findOptimalBreakPoint(remainingText, endIndex);

      String pageText = remainingText.substring(0, breakIndex + 1);
      remainingText = remainingText.substring(breakIndex + 1).trimLeft();

      // Format with proper HTML to preserve styles
      String htmlContent = _formatTextWithStyles(pageText);

      pages.add(EpubPage(
        content: htmlContent,
        plainText: pageText,
        chapterIndex: chapterIndex,
        pageNumberInChapter: pageNumber++,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0,
      ));
    }

    return pages;
  }

  // Find the optimal break point for text to avoid cutting words
  // and prefer breaking at sentence endings
  int _findOptimalBreakPoint(String text, int endIndex) {
    if (endIndex >= text.length) return text.length - 1;

    // First try to find a sentence ending (period, question mark, exclamation)
    for (int i = endIndex; i >= endIndex - 50 && i >= 0; i--) {
      if (i < text.length - 1 &&
          (text[i] == '.' || text[i] == '?' || text[i] == '!') &&
          (i == text.length - 1 || text[i + 1] == ' ')) {
        return i + 1; // Include the space after punctuation
      }
    }

    // Next try paragraph breaks
    int lastParagraphBreak = text.substring(0, endIndex).lastIndexOf('\n\n');
    if (lastParagraphBreak > endIndex - 200 && lastParagraphBreak > 0) {
      return lastParagraphBreak;
    }

    // Next try line breaks
    int lastLineBreak = text.substring(0, endIndex).lastIndexOf('\n');
    if (lastLineBreak > endIndex - 100 && lastLineBreak > 0) {
      return lastLineBreak;
    }

    // Finally, fall back to word boundaries
    int lastSpace = text.substring(0, endIndex).lastIndexOf(' ');
    if (lastSpace > 0) {
      return lastSpace;
    }

    // If all else fails, just break at endIndex-1
    return endIndex - 1;
  }

  // Format text with proper HTML styling
  String _formatTextWithStyles(String text) {
    // Simple approach to identify headings and apply formatting
    if (text.trim().startsWith('#') && text.contains('\n')) {
      // Markdown-style heading
      String firstLine = text.substring(0, text.indexOf('\n')).trim();
      String restOfText = text.substring(text.indexOf('\n')).trim();

      int headerLevel = 1;
      while (firstLine.startsWith('#')) {
        headerLevel = math.min(6, headerLevel + 1);
        firstLine = firstLine.substring(1).trim();
      }

      return '<h$headerLevel style="text-align: center; font-weight: bold;">$firstLine</h$headerLevel>\n<p>$restOfText</p>';
    } else if (text.length < 100 &&
        !text.contains('.') &&
        !text.contains('?') &&
        !text.contains('!')) {
      // Short line with no sentence endings - might be a heading
      return '<h3 style="font-weight: bold;">$text</h3>';
    } else {
      // Regular paragraph
      return '<p>$text</p>';
    }
  }

  // Extract text content from HTML
  String _extractTextFromHtml(String html) {
    // Simple implementation to extract text by removing tags
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Extract content blocks (paragraphs, headers) from HTML with improved formatting
  List<ContentBlock> _extractContentBlocks(String html) {
    final List<ContentBlock> blocks = [];

    // Extract paragraphs and headers with a more robust regex
    // Include more HTML elements that contain text
    final blockRegex = RegExp(
      r'<(p|h[1-6]|div|span|li|blockquote|pre|td|th|figcaption)[^>]*>(.*?)</\1>',
      dotAll: true,
      caseSensitive: false,
    );

    final matches = blockRegex.allMatches(html);

    if (matches.isEmpty) {
      // If no blocks were found, treat the entire content as a single paragraph
      final cleanedText = _extractFormattedText(html);
      if (cleanedText.isNotEmpty) {
        blocks.add(ContentBlock(text: cleanedText, tag: 'p'));
      }
      return blocks;
    }

    for (final match in matches) {
      final tag = match.group(1)?.toLowerCase() ?? 'p';
      String content = match.group(2) ?? '';

      // Handle nested tags with formatting preserved
      content = _extractFormattedText(content);

      // Skip empty blocks
      if (content.isEmpty) {
        continue;
      }

      // Normalize tag types for simpler rendering
      final String normalizedTag;
      if (tag.startsWith('h')) {
        // Keep header tags as they are for proper styling
        normalizedTag = tag;
      } else {
        // Convert other block-level tags to paragraphs but keep inline formatting
        normalizedTag = 'p';
      }

      blocks.add(ContentBlock(text: content, tag: normalizedTag));
    }

    // If we somehow didn't extract any blocks but there is content,
    // use a fallback approach to get the content
    if (blocks.isEmpty) {
      final bodyRegex = RegExp(
        r'<body[^>]*>(.*?)</body>',
        dotAll: true,
        caseSensitive: false,
      );

      final bodyMatch = bodyRegex.firstMatch(html);
      if (bodyMatch != null) {
        final bodyContent = bodyMatch.group(1) ?? '';
        final cleanedText = _extractFormattedText(bodyContent);

        if (cleanedText.isNotEmpty) {
          // Split by double newlines to create paragraph blocks
          final paragraphs = cleanedText.split(RegExp(r'\n\s*\n'));
          for (final paragraph in paragraphs) {
            final trimmed = paragraph.trim();
            if (trimmed.isNotEmpty) {
              blocks.add(ContentBlock(text: trimmed, tag: 'p'));
            }
          }
        }
      }
    }

    return blocks;
  }

  // Extract text from HTML while preserving certain formatting
  String _extractFormattedText(String html) {
    // Replace common formatting tags with markers we can restore later
    String processedHtml = html;

    // Map of tags to replacement markers
    final Map<String, String> formattingMarkers = {
      'b': '**',
      'strong': '**',
      'i': '_',
      'em': '_',
      'u': '__',
      'h1': '# ',
      'h2': '## ',
      'h3': '### ',
      'h4': '#### ',
      'h5': '##### ',
      'h6': '###### ',
    };

    // Process each formatting tag
    formattingMarkers.forEach((tag, marker) {
      final pattern =
          RegExp('<$tag>(.*?)</$tag>', dotAll: true, caseSensitive: false);
      processedHtml = processedHtml.replaceAllMapped(
        pattern,
        (match) => '$marker${match.group(1)}$marker',
      );
    });

    // Replace line breaks
    processedHtml = processedHtml.replaceAll('<br>', '\n');
    processedHtml = processedHtml.replaceAll('<br/>', '\n');
    processedHtml = processedHtml.replaceAll('<br />', '\n');

    // Now remove all remaining HTML tags
    String plainText = _stripHtmlTags(processedHtml);

    // Clean up whitespace
    plainText = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return plainText;
  }

  // Strip HTML tags from content
  String _stripHtmlTags(String html) {
    final buffer = StringBuffer();
    bool inTag = false;

    for (int i = 0; i < html.length; i++) {
      final char = html[i];

      if (char == '<') {
        inTag = true;
        continue;
      }

      if (char == '>') {
        inTag = false;
          continue;
      }

      if (!inTag) {
        buffer.write(char);
      }
    }

    return buffer.toString().trim();
  }

  // Get the appropriate style for a content block
  TextStyle _getStyleForBlock(ContentBlock block) {
    switch (block.tag) {
      case 'h1':
        return TextStyle(
          fontSize: _fontSize * 2.0,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'h2':
        return TextStyle(
          fontSize: _fontSize * 1.5,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'h3':
        return TextStyle(
          fontSize: _fontSize * 1.3,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'h4':
        return TextStyle(
          fontSize: _fontSize * 1.2,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'h5':
        return TextStyle(
          fontSize: _fontSize * 1.1,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'h6':
        return TextStyle(
          fontSize: _fontSize * 1.0,
          height: LINE_HEIGHT_MULTIPLIER,
          fontWeight: FontWeight.bold,
        );
      case 'p':
      default:
        return TextStyle(
          fontSize: _fontSize,
          height: LINE_HEIGHT_MULTIPLIER,
        );
    }
  }

  // Paginate a text block using TextPainter - simplified approach like the example
  List<EpubPage> _paginateBlock(String text, TextStyle style, double maxWidth,
      double maxHeight, int chapterIndex, String chapterTitle,
      {required int blockPages}) {
    // Create a TextPainter for measuring
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final List<EpubPage> pages = [];
    String remainingText = text;
    int pageNumberInChapter = blockPages;

    // Check if this is a heading block that should be treated specially
    bool isHeading = (style.fontSize ?? DEFAULT_FONT_SIZE) > _fontSize ||
        (style.fontWeight == FontWeight.bold && text.length < 200);

    while (remainingText.isNotEmpty) {
      // Measure the text
      textPainter.text = TextSpan(text: remainingText, style: style);
      textPainter.layout(maxWidth: maxWidth);

      // Use the line break factor to ensure we don't get too close to the edge
      double adjustedMaxHeight = maxHeight * LINE_BREAK_FACTOR;

      // Find where the text would be cut off at maxHeight
      int endIndex = textPainter
          .getPositionForOffset(Offset(maxWidth, adjustedMaxHeight))
          .offset;

      // If we can't fit any text or we can fit all text
      if (endIndex == 0 || endIndex >= remainingText.length) {
        // Create a page with the remaining text
        String tag = isHeading ? 'h1' : 'p';
        String styleAttribute =
            isHeading ? ' style="text-align: center; font-weight: bold;"' : '';
        String pageContent = '<$tag$styleAttribute>${remainingText}</$tag>';

        pages.add(EpubPage(
          content: pageContent,
          plainText: remainingText,
          chapterIndex: chapterIndex,
          pageNumberInChapter: pageNumberInChapter++,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0, // Will be updated later
        ));
        break;
      }

      // Find optimal breaking point using the same logic as _paginateText
      int breakIndex = _findOptimalBreakPoint(remainingText, endIndex);

      // Get the text for this page
      String pageText = remainingText.substring(0, breakIndex + 1);
      remainingText = remainingText.substring(breakIndex + 1).trimLeft();

      // Create a page with this text, applying appropriate styling
      String tag = isHeading ? 'h1' : 'p';
      String styleAttribute =
          isHeading ? ' style="text-align: center; font-weight: bold;"' : '';
      String pageContent = '<$tag$styleAttribute>${pageText.trim()}</$tag>';

      pages.add(EpubPage(
        content: pageContent,
        plainText: pageText.trim(),
        chapterIndex: chapterIndex,
        pageNumberInChapter: pageNumberInChapter++,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0, // Will be updated later
      ));
    }

    return pages;
  }

  // Format a page with HTML structure
  String _formatPageContent(String content) {
    if (content.trim().startsWith('<') && content.trim().endsWith('>')) {
      return content; // Already has HTML tags
    }
    return '<p>${content.trim()}</p>';
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
