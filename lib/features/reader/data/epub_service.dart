import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:isolate';
import 'dart:ui';
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

    // First fix any HTML issues that might cause rendering problems
    String content = html;

    // Preserve line breaks before converting to standardized form
    content = content.replaceAll('<br>', '<br/>');
    content = content.replaceAll('<BR>', '<br/>');

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

  // Calculate pages for a chapter with more accurate text measurement and HTML formatting
  Future<List<EpubPage>> calculatePages(
    String htmlContent,
    int chapterIndex,
    String chapterTitle,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    // Apply HTML formatting enhancements
    final enhancedHtml = _extractTextFromHtml(htmlContent);

    // 1. Split content into logical blocks (paragraphs, headings, etc.)
    final blocks = _extractContentBlocks(enhancedHtml);

    if (_debugMode) {
      print('Chapter $chapterIndex extracted ${blocks.length} content blocks');
    }

    // 2. Calculate pages with HTML formatting preserved
    final List<EpubPage> pages = _paginateHtmlBlocks(blocks, chapterIndex,
        chapterTitle, _viewportWidth, _effectiveViewportHeight);

    if (_debugMode) {
      print(
          'Chapter $chapterIndex paginated in ${stopwatch.elapsedMilliseconds}ms, created ${pages.length} pages');
    }

    return pages;
  }

  // Extract content blocks from HTML - improved version
  List<ContentBlock> _extractContentBlocks(String html) {
    final List<ContentBlock> blocks = [];

    // Use a DOM parser to extract content blocks with proper tag information
    try {
      // Get body content if possible
      String bodyContent = html;
      final bodyMatch =
          RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true).firstMatch(html);
      if (bodyMatch != null) {
        bodyContent = bodyMatch.group(1) ?? html;
      }

      // Find all block-level elements
      final blockRegex = RegExp(
        r'<(p|h[1-6]|div|blockquote|pre|ul|ol|table|figure)[^>]*>(.*?)</\1>',
        dotAll: true,
        caseSensitive: false,
      );

      final matches = blockRegex.allMatches(bodyContent);
      int lastEnd = 0;

      // Process each block match
      for (final match in matches) {
        // Check if there's text between the last match and this one
        if (match.start > lastEnd) {
          final textBetween =
              bodyContent.substring(lastEnd, match.start).trim();
          if (textBetween.isNotEmpty) {
            // Wrap in paragraph if it's not an HTML tag already
            if (!textBetween.startsWith('<')) {
              blocks.add(ContentBlock(
                  text:
                      '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">$textBetween</p>',
                  tag: 'p',
                  isHtml: true));
            } else {
              blocks.add(ContentBlock(
                  text: textBetween, tag: 'unknown', isHtml: true));
            }
          }
        }

        final tag = match.group(1)?.toLowerCase() ?? 'p';
        final content = match.group(0) ?? '';

        if (content.isNotEmpty) {
          blocks.add(ContentBlock(text: content, tag: tag, isHtml: true));
        }

        lastEnd = match.end;
      }

      // Add any remaining content after the last match
      if (lastEnd < bodyContent.length) {
        final remaining = bodyContent.substring(lastEnd).trim();
        if (remaining.isNotEmpty) {
          if (!remaining.startsWith('<')) {
            blocks.add(ContentBlock(
                text:
                    '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">$remaining</p>',
                tag: 'p',
                isHtml: true));
          } else {
            blocks.add(
                ContentBlock(text: remaining, tag: 'unknown', isHtml: true));
          }
        }
      }
    } catch (e) {
      // Fallback if parsing fails
      blocks.add(ContentBlock(text: html, tag: 'body', isHtml: true));
    }

    // If no blocks were found, add the entire content as one block
    if (blocks.isEmpty) {
      blocks.add(ContentBlock(text: html, tag: 'body', isHtml: true));
    }

    return blocks;
  }

  // Paginate HTML blocks while preserving formatting
  List<EpubPage> _paginateHtmlBlocks(
    List<ContentBlock> blocks,
    int chapterIndex,
    String chapterTitle,
    double maxWidth,
    double maxHeight,
  ) {
    final safeMaxHeight =
        maxHeight * 0.96; // Increase from 94% to 96% to allow more content
    double currentPageHeight = 0;
    String currentPageContent = '';
    String currentPagePlainText = '';
    int currentPageNumber = 1;
    List<EpubPage> pages = [];
    int overflowFrequency = 0;

    // Track dialog blocks to adjust estimation for consecutive dialog
    bool previousWasDialog = false;
    int consecutiveDialogCount = 0;

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // Special handling for chapter titles - always put them on a new page
      if (block.tag == 'h1' || block.tag == 'h2') {
        if (currentPageContent.isNotEmpty) {
          pages.add(EpubPage(
            content: currentPageContent,
            plainText: currentPagePlainText,
            chapterIndex: chapterIndex,
            pageNumberInChapter: currentPageNumber++,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0,
          ));
          currentPageContent = '';
          currentPagePlainText = '';
          currentPageHeight = 0;
        }

        // Add chapter title block directly to a new page
        final titleHeight = _estimateBlockHeight(block.text, maxWidth) *
            1.1; // 10% extra for titles

        if (titleHeight > safeMaxHeight) {
          _splitAndAddLargeBlock(block, maxWidth, safeMaxHeight, chapterIndex,
              chapterTitle, currentPageNumber++, pages);
        } else {
          currentPageContent = block.text;
          currentPagePlainText = _stripHtmlTags(block.text);
          currentPageHeight = titleHeight;
        }

        continue;
      }

      // Check if this is a dialog block (contains dialog punctuation)
      bool isDialog = block.tag == 'p' && block.text.contains('"') ||
          block.text.contains("'") ||
          block.text.contains('?') ||
          block.text.contains('!');

      if (isDialog) {
        if (previousWasDialog) {
          consecutiveDialogCount++;
        } else {
          consecutiveDialogCount = 1;
        }
        previousWasDialog = true;
      } else {
        previousWasDialog = false;
        consecutiveDialogCount = 0;
      }

      // Calculate block height with adjustments
      double blockHeight = _estimateBlockHeight(block.text, maxWidth);

      // Adjust for dialog when necessary (less conservative than before)
      if (isDialog && consecutiveDialogCount > 1) {
        blockHeight *=
            1.02; // 2% increase for consecutive dialog (less than before)
      }

      // Check if this block alone exceeds the safe height
      if (blockHeight > safeMaxHeight) {
        // If we already have content on the page, finalize it first
        if (currentPageContent.isNotEmpty) {
          pages.add(EpubPage(
            content: currentPageContent,
            plainText: currentPagePlainText,
            chapterIndex: chapterIndex,
            pageNumberInChapter: currentPageNumber++,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0,
          ));
          currentPageContent = '';
          currentPagePlainText = '';
          currentPageHeight = 0;
        }

        // Split this large block across multiple pages
        _splitAndAddLargeBlock(block, maxWidth, safeMaxHeight, chapterIndex,
            chapterTitle, currentPageNumber, pages);

        currentPageNumber +=
            pages.length - (pages.isEmpty ? 0 : pages.length - 1);
        continue;
      }

      // If adding this block would exceed the page height, create a new page
      if (currentPageHeight + blockHeight > safeMaxHeight) {
        // If it's a paragraph, try to split it
        if (block.tag == 'p' && _stripHtmlTags(block.text).length > 50) {
          // Calculate how much of the page is already filled
          double fillRatio = currentPageHeight / safeMaxHeight;

          // Adjust target fill based on current fill and overflow history
          double targetFill = 0.85;
          if (fillRatio < 0.7) {
            targetFill =
                0.90; // More aggressive fill if page is less than 70% full
          } else if (overflowFrequency > 3) {
            targetFill =
                0.82; // More conservative if we've had multiple overflows
          }

          // Try to split the paragraph
          final splitResult = _splitParagraphBlock(
              block, maxWidth, safeMaxHeight, currentPageHeight, targetFill);

          if (splitResult.firstPart.isNotEmpty) {
            // Add the first part to the current page
            currentPageContent += splitResult.firstPart;
            currentPagePlainText += _stripHtmlTags(splitResult.firstPart);

            // Create the current page
            pages.add(EpubPage(
              content: currentPageContent,
              plainText: currentPagePlainText,
              chapterIndex: chapterIndex,
              pageNumberInChapter: currentPageNumber++,
              chapterTitle: chapterTitle,
              absolutePageNumber: 0,
            ));

            // Start a new page with the second part
            currentPageContent = splitResult.secondPart;
            currentPagePlainText = _stripHtmlTags(splitResult.secondPart);
            currentPageHeight =
                _estimateBlockHeight(splitResult.secondPart, maxWidth);
            continue;
          }
        }

        // If we couldn't split or it's not a paragraph, create a new page
        pages.add(EpubPage(
          content: currentPageContent,
          plainText: currentPagePlainText,
          chapterIndex: chapterIndex,
          pageNumberInChapter: currentPageNumber++,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0,
        ));

        // Start a new page with this block
        currentPageContent = block.text;
        currentPagePlainText = _stripHtmlTags(block.text);
        currentPageHeight = blockHeight;
      } else {
        // Add this block to the current page
        currentPageContent += block.text;
        currentPagePlainText += _stripHtmlTags(block.text);
        currentPageHeight += blockHeight;
      }
    }

    // Don't forget the last page if it has content
    if (currentPageContent.isNotEmpty) {
      pages.add(EpubPage(
        content: currentPageContent,
        plainText: currentPagePlainText,
        chapterIndex: chapterIndex,
        pageNumberInChapter: currentPageNumber,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0,
      ));
    }

    return pages;
  }

  // Estimate the height of a block of HTML content
  double _estimateBlockHeight(String html, double maxWidth) {
    final plainText = _stripHtmlTags(html);
    if (plainText.isEmpty) return 0;

    double fontSize = 16.0; // default font size
    double lineHeight = 1.5; // default line height
    double topMargin = 0.0;
    double bottomMargin = 0.0;

    // Apply margin based on HTML tag
    if (html.startsWith('<h1')) {
      fontSize = 24.0;
      lineHeight = 1.3;
      topMargin = 20.0;
      bottomMargin = 16.0;
    } else if (html.startsWith('<h2')) {
      fontSize = 22.0;
      lineHeight = 1.3;
      topMargin = 18.0;
      bottomMargin = 14.0;
    } else if (html.startsWith('<h3')) {
      fontSize = 20.0;
      lineHeight = 1.3;
      topMargin = 16.0;
      bottomMargin = 12.0;
    } else if (html.startsWith('<p')) {
      topMargin = 8.0;
      bottomMargin = 8.0;
    } else if (html.startsWith('<img')) {
      // Fixed height for images plus margins
      return 200.0 + 16.0;
    }

    // Estimate characters per line based on average character width
    double avgCharWidth = 8.0; // average width of a character in pixels
    int charsPerLine = (maxWidth / avgCharWidth).floor();

    // Calculate number of lines needed
    int textLength = plainText.length;

    // Safety factor adjustments
    double safetyFactor =
        0.6; // Base safety factor, less conservative than before

    // Adjust for text complexity
    if (textLength > 500) {
      safetyFactor *= 1.02; // Slight increase for long paragraphs
    }

    // Check for dialog or complex text patterns
    bool hasDialog = html.contains('"') || html.contains("'");
    bool hasPunctuation = false;

    // Calculate punctuation ratio using proper RegExp format
    if (plainText.length > 20) {
      final punctuationMatches =
          RegExp(r'''[,.;:!?"'\-—]''').allMatches(plainText).length;
      final punctuationRatio = punctuationMatches / plainText.length;

      if (punctuationRatio > 0.08) {
        hasPunctuation = true;
        safetyFactor *= 1.03; // 3% increase for text with lots of punctuation
      }
    }

    // Adjust for very long words
    bool hasLongWords = plainText.split(' ').any((word) => word.length > 12);
    if (hasLongWords) {
      safetyFactor *= 1.02; // 2% increase for long words
    }

    // Adjust for dialog-heavy content
    if (hasDialog) {
      safetyFactor *= 1.02; // 2% increase for dialog (less than before)
    }

    // Additional wordwrap factor for short paragraphs
    if (textLength < 200 && textLength > 50) {
      safetyFactor *= 1.01; // Small increase for medium-short paragraphs
    }

    // For very short paragraphs, be more conservative to prevent overflow
    if (textLength < 50 && textLength > 0) {
      final wordsPerLine =
          (charsPerLine / 5).floor(); // Approx 5 chars per word
      final numLines =
          math.max(1, (plainText.split(' ').length / wordsPerLine).ceil());
      return (topMargin + (numLines * fontSize * lineHeight) + bottomMargin) *
          1.1;
    }

    // For normal text, calculate lines more precisely
    final wordCount = plainText.split(' ').length;
    final avgWordLength = textLength / wordCount;
    final wordsPerLine =
        (charsPerLine / (avgWordLength + 1)).floor(); // +1 for space
    final numLines = math.max(1, (wordCount / wordsPerLine).ceil());

    // Calculate total height with safety factor
    final calculatedHeight =
        topMargin + (numLines * fontSize * lineHeight) + bottomMargin;
    return calculatedHeight * safetyFactor;
  }

  // Split a large block across multiple pages
  void _splitAndAddLargeBlock(
      ContentBlock block,
      double maxWidth,
      double maxHeight,
      int chapterIndex,
      String chapterTitle,
      int startPageNumber,
      List<EpubPage> pages) {
    // Handle text blocks by splitting at character level if needed
    if (block.tag == 'p' || block.tag == 'div' || block.tag == 'span') {
      String text = _stripHtmlTags(block.text);
      final totalHeight = _estimateBlockHeight(block.text, maxWidth);
      final chars = text.length;

      // Estimate how many characters fit on one page
      final estimatedCharsPerPage = (chars * (maxHeight / totalHeight)).floor();

      if (estimatedCharsPerPage <= 0) {
        // Fallback for very small blocks
        pages.add(EpubPage(
            content: block.text,
            plainText: text,
            chapterIndex: chapterIndex,
            pageNumberInChapter: startPageNumber,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0));
        return;
      }

      // Split text and create pages
      int offset = 0;
      int pageNum = startPageNumber;

      while (offset < text.length) {
        int endOffset = math.min(offset + estimatedCharsPerPage, text.length);

        // Create a page with this content segment
        final htmlWrapper = block.tag == 'p'
            ? '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">${text.substring(offset, endOffset)}</p>'
            : '<div>${text.substring(offset, endOffset)}</div>';

        pages.add(EpubPage(
            content: htmlWrapper,
            plainText: text.substring(offset, endOffset),
            chapterIndex: chapterIndex,
            pageNumberInChapter: pageNum++,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0));

        offset = endOffset;
      }
    } else {
      // For non-paragraphs just put the entire block on a page by itself
      pages.add(EpubPage(
          content: block.text,
          plainText: _stripHtmlTags(block.text),
          chapterIndex: chapterIndex,
          pageNumberInChapter: startPageNumber,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0));
    }
  }

  // Split a paragraph block to better fit current page
  _ParagraphSplitResult _splitParagraphBlock(
    ContentBlock block,
    double maxWidth,
    double remainingHeight,
    double currentPageHeight,
    double targetFill,
  ) {
    if (block.tag != 'p' || block.text.isEmpty) {
      return _ParagraphSplitResult('', block.text);
    }

    // Extract text without HTML tags
    final fullText = _stripHtmlTags(block.text);

    // Estimate how many characters we can fit in the remaining height
    // Characters per line approximation
    final charWidth = 8; // Approximate width of a character in pixels
    final charsPerLine = (maxWidth / charWidth).floor();

    // Lines that can fit in remaining height
    final lineHeight = 20; // Approximate line height in pixels
    final linesAvailable = (remainingHeight / lineHeight).floor();

    // Target number of characters that should fill the remaining space
    final targetChars = (charsPerLine * linesAvailable * targetFill).floor();

    // Find the best place to break the paragraph
    int breakIndex = _findOptimalSplitPoint(fullText, targetChars);

    if (breakIndex <= 50 || breakIndex >= fullText.length - 50) {
      // No good split point found, or split point is too close to start/end
      return _ParagraphSplitResult('', block.text);
    }

    // Extract original paragraph style
    String pStyle = 'style="text-indent: 1.5em; margin-bottom: 0.5em;"';
    final styleMatch =
        RegExp(r'''<p\s+style=["\'](.*?)["\']''').firstMatch(block.text);
    if (styleMatch != null) {
      pStyle = 'style="${styleMatch.group(1)}"';
    }

    // Create HTML for both parts, preserving original styling
    final firstPart = '<p $pStyle>${fullText.substring(0, breakIndex)}</p>';

    // For the second part, check if it needs indentation
    // If it's continuing a paragraph, we might want to skip text-indent
    String secondPartStyle = pStyle;
    if (breakIndex > 0) {
      // If previous char was end of sentence punctuation, keep indentation
      bool isEndOfSentence = false;
      final char = fullText[breakIndex - 1];
      isEndOfSentence = char == '.' || char == '?' || char == '!';

      // If not at end of sentence, remove indentation for continuation
      if (!isEndOfSentence) {
        secondPartStyle = pStyle.replaceAll('text-indent: 1.5em;', '');
      }
    }

    final secondPart =
        '<p $secondPartStyle>${fullText.substring(breakIndex)}</p>';
    return _ParagraphSplitResult(firstPart, secondPart);
  }

  // Create an EpubPage from content blocks
  EpubPage _createPageFromBlocks(List<ContentBlock> blocks, int chapterIndex,
      int pageNumber, String chapterTitle) {
    // Combine HTML content from all blocks
    final StringBuffer htmlContent = StringBuffer();
    final StringBuffer plainText = StringBuffer();

    for (final block in blocks) {
      htmlContent.write(block.text);
      plainText.write('${_stripHtmlTags(block.text)} ');
    }

    return EpubPage(
      content: htmlContent.toString(),
      plainText: plainText.toString().trim(),
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumber,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0, // Will be updated later
    );
  }

  // Find an optimal split point - prioritizing sentence ends, then commas, then spaces
  int _findOptimalSplitPoint(String text, int targetIndex) {
    // Ensure targetIndex is within bounds
    int safeTarget = math.min(targetIndex, text.length - 1);
    safeTarget = math.max(50, safeTarget);

    // Search window: look up to 30% before target for a good break point
    final int minIndex = (safeTarget * 0.7).floor();

    // First look for paragraph breaks (double newline) - highest priority
    for (int i = safeTarget; i >= minIndex; i--) {
      if (i < text.length - 1 &&
          text[i] == '\n' &&
          i > 0 &&
          text[i - 1] == '\n') {
        return i + 1;
      }
    }

    // Next look for sentence endings
    for (int i = safeTarget; i >= minIndex; i--) {
      if (i < text.length - 1 &&
          (text[i] == '.' || text[i] == '?' || text[i] == '!') &&
          (i == text.length - 1 || text[i + 1] == ' ' || text[i + 1] == '\n')) {
        return i + 1; // Include the space/newline after punctuation
      }
    }

    // Then look for commas, semicolons, or colons followed by space
    for (int i = safeTarget; i >= minIndex; i--) {
      if (i < text.length - 1 &&
          (text[i] == ',' || text[i] == ';' || text[i] == ':') &&
          (i == text.length - 1 || text[i + 1] == ' ' || text[i + 1] == '\n')) {
        return i + 1;
      }
    }

    // Next look for logical breaks like em dashes
    for (int i = safeTarget; i >= minIndex; i--) {
      if (i < text.length - 1 &&
          (text[i] == '—' || text[i] == '-' || text[i] == '–') &&
          (i == text.length - 1 || text[i + 1] == ' ' || text[i + 1] == '\n')) {
        return i + 1;
      }
    }

    // Finally look for spaces between words
    for (int i = safeTarget; i >= minIndex; i--) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i + 1;
      }
    }

    // If no good break point is found, just return the target index
    return safeTarget;
  }

  // Override the _formatTextWithStyles method to just return the HTML directly
  String _formatTextWithStyles(String text) {
    // No need for formatting since we're working with HTML directly
    if (text.trim().startsWith('<') && text.trim().endsWith('>')) {
      return text; // Already has HTML
    }
    return '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">${text.trim()}</p>';
  }

  // Extract text content from HTML while preserving formatting
  String _extractTextFromHtml(String html) {
    // Don't strip HTML tags since we want to preserve formatting
    // Instead, clean up the HTML to make it more renderable
    if (html.isEmpty) return '';

    // First, standardize some common formatting tags and ensure they have proper closing tags
    String content = html;

    // Make sure paragraphs have proper spacing and formatting
    content = content.replaceAll(
        RegExp(r'<p>\s*</p>'), ''); // Remove empty paragraphs

    // Enhance paragraph styling with indentation and margins
    content = content.replaceAll(
        '<p>', '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">');

    // Enhance heading styling
    content = content.replaceAll('<h1>',
        '<h1 style="text-align: center; font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h2>',
        '<h2 style="text-align: center; font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h3>',
        '<h3 style="font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h4>',
        '<h4 style="font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h5>',
        '<h5 style="font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h6>',
        '<h6 style="font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');

    // Make sure emphasis and strong tags have proper styling
    content = content.replaceAll('<i>', '<em style="font-style: italic;">');
    content = content.replaceAll('</i>', '</em>');
    content = content.replaceAll('<b>', '<strong style="font-weight: bold;">');
    content = content.replaceAll('</b>', '</strong>');

    // Enhance blockquote and other common elements
    content = content.replaceAll('<blockquote>',
        '<blockquote style="margin-left: 2em; font-style: italic;">');
    content = content.replaceAll(
        '<hr>', '<hr style="width: 50%; margin: 1em auto;">');

    // Center div elements with center class
    content = content.replaceAll(
        '<div class="center">', '<div style="text-align: center;">');
    content = content.replaceAll(
        '<div class="centered">', '<div style="text-align: center;">');

    // Finally, add a wrapper that ensures block-level formatting is applied correctly
    if (!content.trim().startsWith('<')) {
      // Plain text - wrap in paragraph
      content =
          '<p style="text-indent: 1.5em; margin-bottom: 0.5em;">${content.trim()}</p>';
    }

    return content;
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
