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

      // Calculate pages
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

/// A class to calculate and paginate EPUB content
class EpubPageCalculator {
  static const double DEFAULT_FONT_SIZE = 23.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 32.0;
  static const double PAGE_HEIGHT_FRACTION = 0.95;

  // Font metrics constants
  static const double AVERAGE_CHAR_WIDTH_RATIO = 0.6;
  static const double WORD_SPACING_RATIO = 0.3;
  static const double AVERAGE_WORD_LENGTH = 5.5;

  // Cache structures
  final Map<int, List<EpubPage>> _pageCache = {};
  final Map<String, TextStyle> _styleCache = {};
  // Improved width measurement cache with capacity limit
  final LRUCache<String, double> _textWidthCache =
      LRUCache<String, double>(5000);

  // Paragraph height cache
  final Map<String, double> _paragraphHeightCache = {};

  // Reusable text painter pool
  final List<TextPainter> _textPainterPool =
      List.generate(5, (_) => TextPainter(textDirection: TextDirection.ltr));

  // Stopwatch for performance monitoring
  final Stopwatch _stopwatch = Stopwatch();

  // Make these non-late final fields regular fields since we'll update them
  final double _viewportWidth;
  final double _viewportHeight;
  double _fontSize;
  final double _effectiveViewportHeight;
  int _wordsPerLine = 0;
  int _linesPerPage = 0;
  int _wordsPerPage = 0;

  // Performance statistics
  int _totalBlocksProcessed = 0;
  int _cacheHits = 0;

  // Debug flag for tracking page calculations
  final bool _debugMode = false;

  EpubPageCalculator({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = DEFAULT_FONT_SIZE,
  })  : _viewportWidth = viewportWidth - (PAGE_PADDING * 2),
        _viewportHeight = viewportHeight * PAGE_HEIGHT_FRACTION,
        _fontSize = fontSize,
        _effectiveViewportHeight =
            (viewportHeight * PAGE_HEIGHT_FRACTION) - (PAGE_PADDING * 2) {
    _calculateMetrics();
  }

  void _calculateMetrics() {
    // Calculate available space with exact padding
    final availableWidth = _viewportWidth;
    final availableHeight = _effectiveViewportHeight;

    // Calculate line metrics with exact measurements
    final charWidth = _fontSize * AVERAGE_CHAR_WIDTH_RATIO;
    final wordSpacing = _fontSize * WORD_SPACING_RATIO;
    final averageWordWidth = (charWidth * AVERAGE_WORD_LENGTH) + wordSpacing;
    final lineHeight = _fontSize * LINE_HEIGHT_MULTIPLIER;

    // Calculate maximum words per line
    _wordsPerLine = ((availableWidth / averageWordWidth) * 0.95).floor();

    // Calculate maximum lines per page - use 0.9 to provide some safety margin
    _linesPerPage = ((availableHeight / lineHeight) * 0.9).floor();

    // Calculate total words per page
    _wordsPerPage = _wordsPerLine * _linesPerPage;

    // Apply device-specific maximum (moderate limits to prevent both overflow and underfill)
    final deviceConstraints = _getDeviceSpecificConstraints();
    _wordsPerPage = math.min(_wordsPerPage, deviceConstraints);

    if (_debugMode) {
      print('Calculated metrics:');
      print('- Viewport: ${_viewportWidth}x${_viewportHeight}');
      print('- Available: ${availableWidth}x${availableHeight}');
      print('- Words per line: $_wordsPerLine');
      print('- Lines per page: $_linesPerPage');
      print('- Words per page: $_wordsPerPage');
    }
  }

  int _getDeviceSpecificConstraints() {
    // Base maximum on viewport size with balanced limits
    final viewportArea = _viewportWidth * _viewportHeight;
    final baseMaxWords = (viewportArea / (_fontSize * _fontSize * 1.35))
        .floor(); // Balanced multiplier

    // Moderate limits for each device category
    if (_viewportWidth < 400) {
      // Small phones
      return math.min(baseMaxWords, 250);
    } else if (_viewportWidth < 600) {
      // Regular phones
      return math.min(baseMaxWords, 320);
    } else if (_viewportWidth < 800) {
      // Large phones
      return math.min(baseMaxWords, 400);
    } else {
      // Tablets and larger
      return math.min(baseMaxWords, 450);
    }
  }

  void updateFontSize(double newFontSize) {
    _fontSize = newFontSize;
    _calculateMetrics();
    _pageCache.clear();
    _styleCache.clear();
    _textWidthCache.clear(); // Clear width cache when font size changes
    _paragraphHeightCache.clear();
  }

  // Calculate pages for a chapter with balanced content
  Future<List<EpubPage>> calculatePages(
    String htmlContent,
    int chapterIndex,
    String chapterTitle,
  ) async {
    _stopwatch.reset();
    _stopwatch.start();

    // Check cache first
    if (_pageCache.containsKey(chapterIndex)) {
      return _pageCache[chapterIndex]!;
    }

    // Reset performance counters
    _totalBlocksProcessed = 0;
    _cacheHits = 0;

    // Parse HTML content
    final parsedContent = await _parseHtmlContent(htmlContent);
    final parsingTime = _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();
    _stopwatch.start();

    // Calculate page breaks
    final pages =
        _calculatePageBreaks(parsedContent, chapterIndex, chapterTitle);

    // Perform post-processing to balance pages if needed
    final balancedPages = _balancePages(pages, chapterIndex, chapterTitle);

    final paginationTime = _stopwatch.elapsedMilliseconds;

    // Cache results
    _pageCache[chapterIndex] = balancedPages;

    // Debug timing
    if (balancedPages.isNotEmpty) {
      final cacheHitRate = _totalBlocksProcessed > 0
          ? (_cacheHits / _totalBlocksProcessed * 100).toStringAsFixed(1)
          : '0';

      print(
          'Chapter $chapterIndex: parsing ${parsingTime}ms, pagination ${paginationTime}ms, ' +
              '${balancedPages.length} pages, cache hit rate: $cacheHitRate%');
    }

    return balancedPages;
  }

  // Balance pages to ensure even content distribution
  List<EpubPage> _balancePages(
      List<EpubPage> originalPages, int chapterIndex, String chapterTitle) {
    if (originalPages.length <= 1) {
      return originalPages; // Nothing to balance with just one page
    }

    // Check for first page overflow by analyzing content
    final firstPageContent = originalPages.first.content;
    final firstPageHeight = _estimateContentHeight(firstPageContent);

    // If first page looks fine, return original pages
    if (firstPageHeight <= _effectiveViewportHeight * 0.95) {
      return originalPages;
    }

    if (_debugMode) {
      print(
          'First page might overflow with height $firstPageHeight, attempting to rebalance');
    }

    // Extract content from first page for reprocessing
    final firstPageText = _extractTextContent(firstPageContent);

    // If less than 3 pages, perform simple rebalancing
    if (originalPages.length < 3) {
      return _simpleRebalance(
          firstPageText, originalPages, chapterIndex, chapterTitle);
    }

    // For longer content, keep original pages but fix the first page
    return _rebalanceFirstPage(
        firstPageText, originalPages, chapterIndex, chapterTitle);
  }

  // Extract text content from HTML
  String _extractTextContent(String html) {
    // Simple extraction by removing HTML tags
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Simple rebalancing for short chapters
  List<EpubPage> _simpleRebalance(String firstPageText,
      List<EpubPage> originalPages, int chapterIndex, String chapterTitle) {
    final result = <EpubPage>[];

    // Create a more balanced first page with 75% of the height
    final firstPageWords = firstPageText.split(RegExp(r'\s+'));
    final totalWords = firstPageWords.length;

    // Determine a better split point - aim for 70% of content on first page
    final firstPageWordCount = (totalWords * 0.7).floor();

    // Split the content
    final firstPageContent =
        '<p>${firstPageWords.sublist(0, firstPageWordCount).join(' ')}</p>';
    final secondPageContent =
        '<p>${firstPageWords.sublist(firstPageWordCount).join(' ')}</p>';

    // Create rebalanced pages
    result.add(EpubPage(
      content: firstPageContent,
      chapterIndex: chapterIndex,
      pageNumberInChapter: 1,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0,
    ));

    if (secondPageContent.length > 10) {
      result.add(EpubPage(
        content: secondPageContent,
        chapterIndex: chapterIndex,
        pageNumberInChapter: 2,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0,
      ));
    }

    // If there were more pages, add them
    if (originalPages.length > 2) {
      for (int i = 2; i < originalPages.length; i++) {
        final page = originalPages[i];
        result.add(EpubPage(
          content: page.content,
          chapterIndex: chapterIndex,
          pageNumberInChapter: result.length + 1,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0,
        ));
      }
    }

    return result;
  }

  // Rebalance just the first page for longer chapters
  List<EpubPage> _rebalanceFirstPage(String firstPageText,
      List<EpubPage> originalPages, int chapterIndex, String chapterTitle) {
    final result = <EpubPage>[];

    // For long text, cut off at 80% of the way through
    final firstPageWords = firstPageText.split(RegExp(r'\s+'));
    final cutPoint = (firstPageWords.length * 0.8).floor();

    // Create a shorter first page
    final firstPageContent =
        '<p>${firstPageWords.sublist(0, cutPoint).join(' ')}</p>';

    // Create a new second page with remaining content
    final secondPageContent =
        '<p>${firstPageWords.sublist(cutPoint).join(' ')}</p>';

    // Add first page
    result.add(EpubPage(
      content: firstPageContent,
      chapterIndex: chapterIndex,
      pageNumberInChapter: 1,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0,
    ));

    // Add new second page
    result.add(EpubPage(
      content: secondPageContent,
      chapterIndex: chapterIndex,
      pageNumberInChapter: 2,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0,
    ));

    // Add all remaining pages except the original second page
    // (since we've moved content from page 1 to page 2)
    for (int i = 2; i < originalPages.length; i++) {
      final page = originalPages[i];
      result.add(EpubPage(
        content: page.content,
        chapterIndex: chapterIndex,
        pageNumberInChapter: result.length + 1,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0,
      ));
    }

    if (_debugMode) {
      print(
          'Rebalanced: Original pages: ${originalPages.length}, New pages: ${result.length}');
    }

    return result;
  }

  // Parse HTML content and apply styles (optimized version)
  Future<ParsedContent> _parseHtmlContent(String html) async {
    // Create style cache if not already there
    if (_styleCache.isEmpty) {
      _styleCache['p'] = TextStyle(
        fontSize: _fontSize,
        height: LINE_HEIGHT_MULTIPLIER,
      );
      _styleCache['h1'] = TextStyle(
        fontSize: _fontSize * 2.0,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
      _styleCache['h2'] = TextStyle(
        fontSize: _fontSize * 1.5,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
      _styleCache['h3'] = TextStyle(
        fontSize: _fontSize * 1.3,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
      _styleCache['h4'] = TextStyle(
        fontSize: _fontSize * 1.2,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
      _styleCache['h5'] = TextStyle(
        fontSize: _fontSize * 1.1,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
      _styleCache['h6'] = TextStyle(
        fontSize: _fontSize * 1.0,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      );
    }

    final blocks = <ContentBlock>[];

    // OPTIMIZATION: Use pre-compiled regex for paragraph/header extraction
    final paragraphRegex = RegExp(
      r'<(p|h[1-6])[^>]*>(.*?)</\1>',
      dotAll: true,
      caseSensitive: false,
    );

    // Extract paragraphs with a single regex pass
    final matches = paragraphRegex.allMatches(html);

    for (final match in matches) {
      final tag = match.group(1) ?? 'p';
      String content = match.group(2) ?? '';

      // More efficient text extraction (avoiding multiple regex operations)
      if (content.contains('<')) {
        // Faster implementation for stripping HTML tags
        content = _stripHtmlTags(content);
      }

      blocks.add(ContentBlock(
        textSpan: TextSpan(
          text: content,
          style: _styleCache[tag] ?? _styleCache['p'],
        ),
        rawHtml: match.group(0) ?? '',
        styles: {'tag': tag},
      ));
    }

    return ParsedContent(blocks: blocks, styles: _styleCache);
  }

  // Faster implementation of HTML tag stripping
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

  // Get a TextPainter from the pool or create a new one
  TextPainter _getTextPainter() {
    if (_textPainterPool.isNotEmpty) {
      return _textPainterPool.removeLast();
    }
    return TextPainter(textDirection: TextDirection.ltr);
  }

  // Return a TextPainter to the pool for reuse
  void _recycleTextPainter(TextPainter painter) {
    painter.text = null;
    if (_textPainterPool.length < 10) {
      // Expanded pool size
      _textPainterPool.add(painter);
    }
  }

  // Measure the height of a block using its TextSpan and available width
  double _measureBlockHeight(ContentBlock block) {
    _totalBlocksProcessed++;

    // Generate cache key (hash of text and style characteristics)
    final String text = block.textSpan.text ?? '';
    final TextStyle style = block.textSpan.style ?? _styleCache['p']!;
    final cacheKey = '${text.length}_${style.fontSize}_${_viewportWidth}';

    // First check the paragraph height cache
    if (_paragraphHeightCache.containsKey(cacheKey)) {
      _cacheHits++;
      return _paragraphHeightCache[cacheKey]!;
    }

    // OPTIMIZATION: For very short text (e.g., headers), use a more accurate calculation
    if (text.length < 100) {
      // More accurate line calculation for short text
      final words = text.split(RegExp(r'\s+'));
      final approximateLines =
          math.max(1, (words.length / _wordsPerLine).ceil());
      final height = approximateLines *
          style.fontSize! *
          (style.height ?? LINE_HEIGHT_MULTIPLIER);

      // Cache the result
      _paragraphHeightCache[cacheKey] = height;
      return height;
    }

    // For longer text, use TextPainter for more accurate measurement
    final textPainter = _getTextPainter();
    textPainter.text = block.textSpan;
    textPainter.layout(maxWidth: _viewportWidth);
    final height = textPainter.height;
    _recycleTextPainter(textPainter);

    // Cache the result (limit cache size to prevent memory issues)
    if (_paragraphHeightCache.length < 1000) {
      _paragraphHeightCache[cacheKey] = height;
    }

    return height;
  }

  // Optimized _measureTextWidth with caching
  double _measureTextWidth(String text, TextStyle style) {
    // Generate cache key
    final fontSize = style.fontSize ?? DEFAULT_FONT_SIZE;
    final cacheKey = '${text.hashCode}_$fontSize';

    // Check cache first
    final cachedValue = _textWidthCache.get(cacheKey);
    if (cachedValue != null) {
      _cacheHits++;
      return cachedValue;
    }

    // OPTIMIZATION: For short words, use more accurate approximation
    if (text.length <= 10) {
      // Improved character width approximation based on character type
      double approxWidth = 0;
      for (var i = 0; i < text.length; i++) {
        final char = text[i];
        // Wide characters (like 'w', 'm') vs narrow characters (like 'i', 'l')
        final charWidthRatio = _isWideCharacter(char)
            ? AVERAGE_CHAR_WIDTH_RATIO * 1.5
            : AVERAGE_CHAR_WIDTH_RATIO * 0.8;
        approxWidth += fontSize * charWidthRatio;
      }
      _textWidthCache.put(cacheKey, approxWidth);
      return approxWidth;
    }

    // Fall back to measurement if not cached
    final textPainter = _getTextPainter();
    textPainter.text = TextSpan(text: text, style: style);
    textPainter.layout();
    final width = textPainter.width;
    _recycleTextPainter(textPainter);

    // Cache result
    _textWidthCache.put(cacheKey, width);
    return width;
  }

  // Helper method to identify wide vs narrow characters for better width estimation
  bool _isWideCharacter(String char) {
    if (char.isEmpty) return false;

    // Wide characters typically include:
    final wideChars = 'mwWM@QOÄÜÖ';

    // Narrow characters:
    final narrowChars = 'il1t\',.|!';

    if (wideChars.contains(char)) {
      return true;
    } else if (narrowChars.contains(char)) {
      return false;
    }

    // Default to average width for other characters
    return false;
  }

  // Helper: if a word is too wide, split it into segments that each fit
  List<String> _splitLongWord(
      String word, TextStyle style, double availableWidth) {
    // Words that are too long will be hyphenated for better page utilization
    final segments = <String>[];
    String currentSegment = "";

    // Try to find natural break points for hyphenation
    final preferredBreakPoints = ['-', '_', '.'];

    int lastBreakPoint = -1;
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      final candidate = currentSegment + char;

      // If we found a natural break point, remember it
      if (preferredBreakPoints.contains(char)) {
        lastBreakPoint = i;
      }

      if (_measureTextWidth(candidate, style) <= availableWidth) {
        currentSegment = candidate;
      } else {
        // If we're at a preferred break point, break there
        if (lastBreakPoint >= 0 && lastBreakPoint > currentSegment.length - 3) {
          // +1 to include the break character
          segments.add(word.substring(0, lastBreakPoint + 1));
          // Continue with the rest of the word
          return segments +
              _splitLongWord(
                  word.substring(lastBreakPoint + 1), style, availableWidth);
        } else if (currentSegment.length > 3) {
          // If segment is long enough, add a hyphen
          segments.add(
              '${currentSegment.substring(0, currentSegment.length - 1)}-');
          // Continue with the rest of the word
          return segments +
              _splitLongWord(word.substring(currentSegment.length - 1), style,
                  availableWidth);
        } else if (currentSegment.isEmpty) {
          // Worst case: split the character
          segments.add(char);
        } else {
          segments.add(currentSegment);
          currentSegment = char;
        }
      }
    }

    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    return segments;
  }

  // Create a page with optimized HTML structure
  EpubPage _createPage(
      String content, int chapterIndex, int pageNumber, String chapterTitle) {
    // Ensure the content has proper HTML structure for better rendering
    final formattedContent = _formatPageContent(content);

    // Detect potential overflow content by measuring approximate height
    final approxContentHeight = _estimateContentHeight(formattedContent);
    final bool potentialOverflow =
        approxContentHeight > _effectiveViewportHeight;

    if (potentialOverflow && _debugMode) {
      print(
          'WARNING: Page $pageNumber may overflow with approx height $approxContentHeight');
    }

    return EpubPage(
      content: formattedContent,
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumber,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0, // Default value, will be updated later if needed
    );
  }

  // Helper method to estimate content height for overflow detection
  double _estimateContentHeight(String content) {
    // Count paragraphs
    final paragraphCount = '<p>'.allMatches(content).length;

    // Estimate lines based on content length and average line length
    final estimatedChars = content.replaceAll(RegExp(r'<[^>]*>'), '').length;
    final estimatedCharsPerLine =
        _wordsPerLine * 5; // Assuming 5 chars per word average
    final estimatedLines = math.max(
        paragraphCount, // Minimum one line per paragraph
        estimatedChars / estimatedCharsPerLine // Or estimate by content length
        );

    return estimatedLines * (_fontSize * LINE_HEIGHT_MULTIPLIER);
  }

  // Format the page content with proper HTML structure
  String _formatPageContent(String content) {
    // If content already has proper structure, return as is
    if (content.trim().startsWith('<') &&
        (content.contains('<p>') || content.contains('<h'))) {
      return content;
    }

    // Otherwise, wrap in paragraph tags for proper rendering
    return '<p>${content.trim()}</p>';
  }

  // Optimized page breaking algorithm - improved to use more page space
  List<EpubPage> _calculatePageBreaks(
      ParsedContent content, int chapterIndex, String chapterTitle) {
    final pages = <EpubPage>[];

    // We work with a buffer (for the page's HTML) and a counter for the filled height.
    final StringBuffer currentPageBuffer = StringBuffer();
    double currentPageHeight = 0.0;

    // Use a safe page height limit to prevent overflow
    final double pageHeightLimit = _effectiveViewportHeight * 0.9;

    // We assume a uniform line height (this could be measured more precisely if needed)
    final double lineHeight = _fontSize * LINE_HEIGHT_MULTIPLIER;

    // Default style for paragraphs:
    final TextStyle defaultStyle = _styleCache['p'] ??
        TextStyle(fontSize: _fontSize, height: LINE_HEIGHT_MULTIPLIER);

    // Track current page for debug purposes
    int currentPageNumber = 1;

    if (_debugMode) {
      print('Starting pagination with height limit: $pageHeightLimit');
    }

    // Process each block (a block might be a paragraph or header)
    for (final block in content.blocks) {
      // Determine the tag and style (if not set, default to paragraph)
      final String tag = block.styles['tag'] ?? 'p';
      // Use a header style if available; otherwise, use the default style.
      final TextStyle style = content.styles[tag] ?? defaultStyle;

      // For headers, we force a page break if it won't fit
      if (tag.startsWith('h')) {
        // Use a slightly smaller multiplier for header height calculation
        final headerHeight = style.fontSize! * LINE_HEIGHT_MULTIPLIER * 1.1;

        // If adding the header would exceed the page limit, start a new page
        if (currentPageHeight + headerHeight > pageHeightLimit &&
            currentPageBuffer.isNotEmpty) {
          pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
              pages.length + 1, chapterTitle));

          if (_debugMode) {
            print(
                'Page $currentPageNumber complete at height $currentPageHeight (max: $pageHeightLimit)');
            currentPageNumber++;
          }

          currentPageBuffer.clear();
          currentPageHeight = 0.0;
        }

        // Write the header
        currentPageBuffer.writeln('<$tag>${block.textSpan.text}</$tag>');
        currentPageHeight += headerHeight;

        if (_debugMode) {
          print(
              'Added header with height $headerHeight, current height: $currentPageHeight');
        }

        continue;
      }

      // For a normal paragraph:
      final String plainText = block.textSpan.text ?? '';
      if (plainText.isEmpty) continue;

      // Calculate paragraph height more accurately
      final approximateWordCount = plainText.split(RegExp(r'\s+')).length;
      final approximateLines = (approximateWordCount / _wordsPerLine).ceil();
      final estimatedParagraphHeight = approximateLines * lineHeight;

      // Add a small spacing between paragraphs
      final paragraphSpacing = lineHeight * 0.2;
      final totalParagraphHeight = estimatedParagraphHeight + paragraphSpacing;

      if (_debugMode) {
        print(
            'Paragraph: $approximateWordCount words, ~$approximateLines lines, estimated height: $estimatedParagraphHeight');
      }

      // Check if this paragraph would overflow the page
      if (currentPageHeight + totalParagraphHeight > pageHeightLimit) {
        // If we already have content and this paragraph would overflow,
        // create a new page first
        if (currentPageBuffer.isNotEmpty) {
          pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
              pages.length + 1, chapterTitle));

          if (_debugMode) {
            print(
                'Page $currentPageNumber complete at height $currentPageHeight (max: $pageHeightLimit)');
            currentPageNumber++;
          }

          currentPageBuffer.clear();
          currentPageHeight = 0.0;
        }

        // If the paragraph is very long (would fill more than 80% of a page),
        // process it specially to break across pages
        if (estimatedParagraphHeight > pageHeightLimit * 0.8) {
          _processLongParagraph(
              plainText,
              currentPageBuffer,
              pages,
              lineHeight,
              pageHeightLimit,
              _viewportWidth,
              style,
              currentPageHeight,
              chapterIndex,
              chapterTitle,
              currentPageNumber);

          // After processing a long paragraph that spans pages, we need to
          // reset our tracking variables
          if (currentPageBuffer.isNotEmpty) {
            currentPageHeight = _estimateCurrentBufferHeight(
                currentPageBuffer.toString(), lineHeight);
          } else {
            currentPageHeight = 0.0;
          }

          // Update page number for debugging
          currentPageNumber = pages.length + 1;

          continue;
        }
      }

      // For paragraphs that fit on the current page
      currentPageBuffer.writeln('<p>${plainText}</p>');
      currentPageHeight += totalParagraphHeight;

      if (_debugMode) {
        print('Added paragraph, new height: $currentPageHeight');
      }
    }

    // Flush any remaining content into a final page
    if (currentPageBuffer.isNotEmpty) {
      pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
          pages.length + 1, chapterTitle));

      if (_debugMode) {
        print(
            'Final page $currentPageNumber complete at height $currentPageHeight');
      }
    }

    return pages;
  }

  // Helper method to estimate the height of current buffer content
  double _estimateCurrentBufferHeight(String content, double lineHeight) {
    // Count number of paragraph tags as a basic estimation
    final paragraphCount = '<p>'.allMatches(content).length;
    // Count estimated number of lines based on content length
    final estimatedLines = content.length / 40; // rough average chars per line

    return math.max(
        paragraphCount * lineHeight, // minimum one line per paragraph
        estimatedLines * lineHeight // or estimated by content length
        );
  }

  // Process a long paragraph that might span multiple pages
  void _processLongParagraph(
      String plainText,
      StringBuffer currentPageBuffer,
      List<EpubPage> pages,
      double lineHeight,
      double pageHeightLimit,
      double availableWidth,
      TextStyle style,
      double currentPageHeight,
      int chapterIndex,
      String chapterTitle,
      int currentPageNumber) {
    if (_debugMode) {
      print('Processing long paragraph that may span pages');
    }

    // Split the text into words
    final List<String> words = plainText.split(RegExp(r'\s+'));

    // Check if we're starting a paragraph on a new page or continuing on current page
    bool isStartOfParagraph = true;

    // Begin paragraph tag if we're starting fresh on the current page
    if (currentPageBuffer.isNotEmpty) {
      currentPageBuffer.write('<p>');
    }

    String currentLine = "";
    double lineWidthSoFar = 0;

    // Track if this is the first page of content
    final bool isFirstPage = pages.isEmpty;
    // Use a more conservative limit for the first page to prevent overflow
    final double effectiveHeightLimit =
        isFirstPage ? pageHeightLimit * 0.85 : pageHeightLimit;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final wordWidth = _measureTextWidth(word, style);

      // Check if this word starts a new line
      if (currentLine.isEmpty) {
        currentLine = word;
        lineWidthSoFar = wordWidth;
      } else {
        // Check if adding this word would exceed line width
        final spaceWidth = _measureTextWidth(' ', style);
        if (lineWidthSoFar + spaceWidth + wordWidth <= availableWidth) {
          // Word fits on current line
          currentLine = '$currentLine $word';
          lineWidthSoFar += spaceWidth + wordWidth;
        } else {
          // Word doesn't fit, start a new line
          currentPageBuffer.write('$currentLine ');
          currentPageHeight += lineHeight;

          // Check if we need a page break - use a slightly lower threshold for first page
          if (currentPageHeight + lineHeight > effectiveHeightLimit) {
            // Close paragraph tag before ending the page
            currentPageBuffer.write('</p>');

            // Create a page
            pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
                pages.length + 1, chapterTitle));

            if (_debugMode) {
              print(
                  'Page $currentPageNumber complete at height $currentPageHeight (max: $effectiveHeightLimit)');
              currentPageNumber++;
            }

            // Clear the buffer and reset height
            currentPageBuffer.clear();
            currentPageHeight = 0;

            // Mark that we're continuing a paragraph on the next page
            isStartOfParagraph = false;

            // Start a new paragraph tag on new page with continuation indicator
            currentPageBuffer.write('<p>');
          }

          // Start a new line with this word
          currentLine = word;
          lineWidthSoFar = wordWidth;
        }
      }

      // Special handling for the last few words on the first page
      // This helps prevent overflow by being extra cautious near page end
      if (isFirstPage &&
          i > words.length * 0.8 &&
          currentPageHeight > effectiveHeightLimit * 0.9) {
        // Force a page break if we're getting close to the end of the first page
        // and still have significant content remaining
        currentPageBuffer.write('$currentLine </p>');

        // Create the first page
        pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
            pages.length + 1, chapterTitle));

        if (_debugMode) {
          print(
              'First page forced break at height $currentPageHeight (max: $effectiveHeightLimit)');
          currentPageNumber++;
        }

        // Clear buffer and set up for next page
        currentPageBuffer.clear();
        currentPageHeight = 0;

        // Mark that we're continuing the paragraph
        isStartOfParagraph = false;

        // Set up the continuation on the next page
        currentPageBuffer.write('<p>');
        currentLine = "";
        lineWidthSoFar = 0;
      }
    }

    // Add the last line if there is one
    if (currentLine.isNotEmpty) {
      currentPageBuffer.write(currentLine);
      currentPageHeight += lineHeight;
    }

    // Close the paragraph tag
    currentPageBuffer.write('</p>');

    if (_debugMode) {
      print(
          'Long paragraph processing complete, final height: $currentPageHeight');
    }
  }

  // Clear the cache
  void clearCache() {
    _pageCache.clear();
    _styleCache.clear();
    _textWidthCache.clear();
    _paragraphHeightCache.clear();
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
