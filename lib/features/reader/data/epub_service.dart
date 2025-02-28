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
  static const double LINE_HEIGHT_MULTIPLIER = 1.1;
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
    final List<EpubPage> pages = [];
    final List<ContentBlock> currentPageBlocks = [];
    double currentPageHeight = 0;
    int pageNumber = 1;
    bool hasChapterTitle = false;

    // Use a more conservative safety margin - 92% of maxHeight to prevent overflow
    // This is reduced from 94% since we're still seeing overflow issues in dialog-heavy content
    final safeMaxHeight = maxHeight * 0.92;

    // Track metrics to adapt the algorithm as we go
    double lastPageFullnessRatio = 0.0;
    double overflowFrequency = 0.0;
    int pagesCreated = 0;

    // Dialog detection - track consecutive dialog paragraphs to apply more conservative spacing
    int consecutiveDialogCount = 0;
    bool lastWasDialog = false;

    // First, check if we need to add chapter title at the top
    if (chapterTitle.isNotEmpty && blocks.isNotEmpty) {
      if (blocks[0].tag.startsWith('h') &&
          blocks[0].text.contains(chapterTitle)) {
        hasChapterTitle = true;
      } else {
        // Add a nicely formatted chapter title at the top
        currentPageBlocks.add(ContentBlock(
            text:
                '<h1 style="text-align: center; font-weight: bold; margin-bottom: 1.2em; margin-top: 0.8em;">$chapterTitle</h1>',
            tag: 'h1',
            isHtml: true));
        currentPageHeight +=
            _estimateBlockHeight('<h1>$chapterTitle</h1>', maxWidth) *
                1.15; // Add 15% extra for titles
        hasChapterTitle = true;
      }
    }

    // Process all blocks
    for (int i = 0; i < blocks.length; i++) {
      var block = blocks[i];

      // Skip if this is a heading that matches the chapter title and we already added the title
      if (hasChapterTitle &&
          block.tag.startsWith('h') &&
          _stripHtmlTags(block.text).trim() == chapterTitle.trim()) {
        continue;
      }

      // Check if this is a dialog (starts with a quotation mark)
      final plainText = _stripHtmlTags(block.text);
      bool isDialog = plainText.trim().startsWith('"') ||
          plainText.trim().startsWith('"') ||
          plainText.contains("said") ||
          plainText.contains("asked") ||
          (plainText.contains('"') && plainText.contains('"'));

      // Special handling for dialog paragraphs
      if (isDialog) {
        if (lastWasDialog) {
          consecutiveDialogCount++;
        } else {
          consecutiveDialogCount = 1;
        }
        lastWasDialog = true;

        // Add proper spacing between dialog paragraphs
        if (currentPageBlocks.isNotEmpty && block.tag == 'p') {
          // Add dialog-specific styling if needed
          if (!block.text.contains('margin-top')) {
            final plainDialog = _stripHtmlTags(block.text);
            final dialogWithSpace =
                '<p style="text-indent: 1.5em; margin-top: 0.8em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">${plainDialog}</p>';
            block = ContentBlock(text: dialogWithSpace, tag: 'p', isHtml: true);
          }
        }
      } else {
        consecutiveDialogCount = 0;
        lastWasDialog = false;
      }

      // Special handling for chapter number blocks (e.g., centered "1")
      bool isChapterNumber = false;
      if (block.tag == 'h1' || block.tag == 'h2') {
        // Check if block is just a number or few characters, likely a chapter number
        final trimmedText = plainText.trim();
        if (trimmedText.length <= 3 && RegExp(r'^\d+$').hasMatch(trimmedText)) {
          isChapterNumber = true;
          // Style chapter numbers to match the shown format
          if (!block.text.contains('text-align: center')) {
            // Replace original block with properly styled chapter number
            final newBlock = ContentBlock(
                text:
                    '<h1 style="text-align: center; font-weight: bold; margin-top: 1.5em; margin-bottom: 1.5em;">$trimmedText</h1>',
                tag: 'h1',
                isHtml: true);
            // This is a shallow replacement that doesn't modify the original list
            block = newBlock;
          }
        }
      }

      // Estimate height of this block with a dialog-specific safety factor if needed
      double dialogFactor = 1.0;
      if (consecutiveDialogCount > 1) {
        // Apply increasingly conservative estimates for consecutive dialog blocks
        dialogFactor = 1.0 + (math.min(consecutiveDialogCount, 5) * 0.035);
      }

      // Add extra height for chapter numbers and other special blocks
      if (isChapterNumber) {
        dialogFactor = 1.2; // Chapter numbers need extra vertical space
      }

      final blockHeight =
          _estimateBlockHeight(block.text, maxWidth) * dialogFactor;

      // Apply dynamic safety adjustment based on previous metrics
      double adjustedMaxHeight = safeMaxHeight;

      if (pagesCreated > 0) {
        // Dynamically adjust based on previous pages
        if (overflowFrequency > 0.12) {
          // We're experiencing overflow frequently, be more conservative
          adjustedMaxHeight =
              safeMaxHeight * (0.96 - (overflowFrequency * 0.08));
        } else if (lastPageFullnessRatio < 0.65 && overflowFrequency < 0.1) {
          // Pages aren't very full and we rarely have overflow, be more aggressive
          adjustedMaxHeight = math.min(safeMaxHeight * 1.01, safeMaxHeight);
        }

        // Check based on content type
        if (block.tag == 'p' && plainText.length > 700) {
          // Long paragraphs need more caution - reduced from 800 to 700 chars
          adjustedMaxHeight = math.min(adjustedMaxHeight, safeMaxHeight * 0.94);
        } else if (isDialog) {
          // Dialog needs extra caution especially multi-line dialog
          adjustedMaxHeight = math.min(adjustedMaxHeight, safeMaxHeight * 0.92);
        } else if (isChapterNumber) {
          // Chapter numbers can be more aggressively packed
          adjustedMaxHeight = math.min(adjustedMaxHeight * 1.05, safeMaxHeight);
        } else if (block.tag.startsWith('h')) {
          // Headings need special handling
          adjustedMaxHeight = math.min(adjustedMaxHeight, safeMaxHeight * 0.96);
        }
      }

      // Special case for TOC pages
      if (block.text.contains('Table of Contents') ||
          (plainText.contains('Contents') && block.tag.startsWith('h'))) {
        // Table of contents pages need different handling
        adjustedMaxHeight = safeMaxHeight * 0.98; // Give TOC more space
      }

      // Ensure our adjustment stays within safe bounds
      adjustedMaxHeight = math.min(adjustedMaxHeight, safeMaxHeight);
      adjustedMaxHeight = math.max(adjustedMaxHeight, safeMaxHeight * 0.88);

      // Special handling for large blocks that might exceed page height
      if (blockHeight > adjustedMaxHeight) {
        // This block is too large for a single page and needs to be split
        if (currentPageBlocks.isNotEmpty) {
          // First, create a page with current blocks
          pages.add(_createPageFromBlocks(
              currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
          pagesCreated++;
          lastPageFullnessRatio = currentPageHeight / adjustedMaxHeight;
          currentPageBlocks.clear();
          currentPageHeight = 0;
        }

        // Now handle the large block by splitting it
        _splitAndAddLargeBlock(
            block,
            maxWidth,
            adjustedMaxHeight *
                0.92, // Even more conservative split target for large blocks
            chapterIndex,
            chapterTitle,
            pageNumber,
            pages);

        // Update metrics
        pageNumber += (blockHeight / adjustedMaxHeight).ceil();
        pagesCreated += (blockHeight / adjustedMaxHeight).ceil();
        lastPageFullnessRatio = 0.9; // Lower assumption for split pages
        continue;
      }

      // When we're approaching page capacity, be more conservative for dialog
      // This helps prevent dialog overflow which is common in novels
      if (currentPageHeight > (adjustedMaxHeight * 0.7) && isDialog) {
        adjustedMaxHeight = adjustedMaxHeight * 0.96;
      }

      // When a page already has content and the next block is a chapter number,
      // force it to start on a new page
      if (isChapterNumber && currentPageBlocks.isNotEmpty) {
        // Start a new page for chapter numbers
        pages.add(_createPageFromBlocks(
            currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
        pagesCreated++;
        lastPageFullnessRatio = currentPageHeight / adjustedMaxHeight;

        // Start a new page with just the chapter number
        currentPageBlocks.clear();
        currentPageBlocks.add(block);
        currentPageHeight = blockHeight;
        continue;
      }

      // Check if this block would fit on the current page
      if (currentPageHeight + blockHeight <= adjustedMaxHeight) {
        // Block fits completely, add it to current page
        currentPageBlocks.add(block);
        currentPageHeight += blockHeight;
      } else if (currentPageHeight <
              adjustedMaxHeight * 0.72 && // Lower threshold to 72%
          block.tag == 'p' &&
          !block.text.contains('<h') &&
          !block.text.contains('<img')) {
        // Page is at least 72% filled but has space, and this is a paragraph that could potentially be split
        // Try to split this block to better fill the page
        final remainingHeight = adjustedMaxHeight - currentPageHeight;

        // Calculate a target fill ratio based on context
        double targetFillRatio = 0.88; // Reduced from 0.90 for safety

        // If the paragraph is very long, be more conservative
        if (plainText.length > 700) {
          targetFillRatio = 0.85; // Reduced from 0.88
        }

        // If this is dialog, be more conservative
        if (isDialog) {
          targetFillRatio = 0.82; // Even more conservative for dialog
        }

        // If we're near the end of the chapter, be more aggressive
        if (i > blocks.length * 0.9) {
          targetFillRatio = math.min(targetFillRatio + 0.02, 0.9);
        }

        final splitResult = _splitParagraphBlock(
            block, maxWidth, remainingHeight, targetFillRatio);

        if (splitResult.firstPart.isNotEmpty) {
          // Add the first part to the current page
          currentPageBlocks.add(ContentBlock(
              text: splitResult.firstPart, tag: 'p', isHtml: true));

          // Double-check that adding this won't cause overflow
          final firstPartHeight =
              _estimateBlockHeight(splitResult.firstPart, maxWidth) *
                  (isDialog ? 1.08 : 1.0); // Extra safety for dialog

          if (currentPageHeight + firstPartHeight > adjustedMaxHeight) {
            // Risk of overflow, remove the last block and create the page without it
            currentPageBlocks.removeLast();

            if (currentPageBlocks.isNotEmpty) {
              pages.add(_createPageFromBlocks(
                  currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
              pagesCreated++;
              lastPageFullnessRatio = currentPageHeight / adjustedMaxHeight;

              // Start new page with the entire original block
              currentPageBlocks.clear();
              currentPageBlocks.add(block);
              currentPageHeight = blockHeight;
    } else {
              // This was the only block, try to put a smaller portion on this page
              final moreConservativeSplit = _splitParagraphBlock(
                  block,
                  maxWidth,
                  adjustedMaxHeight * 0.65, // Smaller target, reduced from 0.7
                  0.65 // Much more conservative fill ratio, reduced from 0.7
                  );

              if (moreConservativeSplit.firstPart.isNotEmpty) {
                currentPageBlocks.add(ContentBlock(
                    text: moreConservativeSplit.firstPart,
                    tag: 'p',
                    isHtml: true));

                pages.add(_createPageFromBlocks(currentPageBlocks, chapterIndex,
                    pageNumber++, chapterTitle));
                pagesCreated++;

                // Start new page with second part
                currentPageBlocks.clear();
                if (moreConservativeSplit.secondPart.isNotEmpty) {
                  currentPageBlocks.add(ContentBlock(
                      text: moreConservativeSplit.secondPart,
                      tag: 'p',
                      isHtml: true));
                  currentPageHeight = _estimateBlockHeight(
                      moreConservativeSplit.secondPart, maxWidth);
                } else {
                  currentPageHeight = 0;
                }
              } else {
                // Couldn't find a good split, use the original block
                currentPageBlocks.add(block);
                currentPageHeight = blockHeight;
              }
            }
          } else {
            // Safe to add, create page with all blocks including split part
            pages.add(_createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
            pagesCreated++;
            lastPageFullnessRatio =
                (currentPageHeight + firstPartHeight) / adjustedMaxHeight;

            // Start a new page with the remainder
            currentPageBlocks.clear();
            currentPageHeight = 0;

            // Add second part to new page if it exists
            if (splitResult.secondPart.isNotEmpty) {
              currentPageBlocks.add(ContentBlock(
                  text: splitResult.secondPart, tag: 'p', isHtml: true));
              currentPageHeight =
                  _estimateBlockHeight(splitResult.secondPart, maxWidth);
            }
          }
        } else {
          // Could not split effectively, add page and put entire block on next page
          pages.add(_createPageFromBlocks(
              currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
          pagesCreated++;
          lastPageFullnessRatio = currentPageHeight / adjustedMaxHeight;

          // Start a new page with this block
          currentPageBlocks.clear();
          currentPageBlocks.add(block);
          currentPageHeight = blockHeight;
        }
      } else {
        // Block doesn't fit and we can't/shouldn't split it
        // Create a page with current blocks if any
        if (currentPageBlocks.isNotEmpty) {
          pages.add(_createPageFromBlocks(
              currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
          pagesCreated++;
          lastPageFullnessRatio = currentPageHeight / adjustedMaxHeight;
        }

        // Start a new page with this block
        currentPageBlocks.clear();
        currentPageBlocks.add(block);
        currentPageHeight = blockHeight;
      }

      // Update overflow frequency metric based on how full the last page was
      if (lastPageFullnessRatio > 0.96) {
        // This page was potentially overflowing
        overflowFrequency =
            (overflowFrequency * pagesCreated + 1) / (pagesCreated + 1);
      } else {
        // Normal page, decrease the overflow frequency metric
        overflowFrequency =
            (overflowFrequency * pagesCreated) / (pagesCreated + 1);
      }
    }

    // Add the last page if there are remaining blocks
    if (currentPageBlocks.isNotEmpty) {
      pages.add(_createPageFromBlocks(
          currentPageBlocks, chapterIndex, pageNumber, chapterTitle));
    }

    return pages;
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
    double fillFactor,
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
    final targetChars = (charsPerLine * linesAvailable * fillFactor).floor();

    // Find the best place to break the paragraph
    int breakIndex = _findOptimalSplitPoint(fullText, targetChars);

    if (breakIndex <= 50 || breakIndex >= fullText.length - 50) {
      // No good split point found, or split point is too close to start/end
      return _ParagraphSplitResult('', block.text);
    }

    // Extract original paragraph style
    String pStyle =
        'style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word;"';
    final styleMatch =
        RegExp(r'''<p\s+style=["'](.*?)["']''').firstMatch(block.text);
    if (styleMatch != null) {
      pStyle = 'style="${styleMatch.group(1)}"';
      // Ensure justification is included in the style
      if (!pStyle.contains('text-align')) {
        pStyle = pStyle.replaceFirst('style="',
            'style="text-align: justify; text-justify: inter-word; ');
      }
    }

    // Create HTML for both parts, preserving original styling
    final firstPart =
        '<p $pStyle>${fullText.substring(0, breakIndex).trim()}</p>';

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
        '<p $secondPartStyle>${fullText.substring(breakIndex).trim()}</p>';
    return _ParagraphSplitResult(firstPart, secondPart);
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

  // Create an EpubPage from content blocks
  EpubPage _createPageFromBlocks(
    List<ContentBlock> blocks,
    int chapterIndex,
    int pageNumber,
    String chapterTitle,
  ) {
    final contentBuilder = StringBuffer();
    final plainTextBuilder = StringBuffer();

    for (final block in blocks) {
      contentBuilder.write(block.text);
      contentBuilder.write('\n'); // Add small spacing between blocks
      plainTextBuilder.write(_stripHtmlTags(block.text));
      plainTextBuilder.write(' '); // Space between blocks in plain text
    }

    return EpubPage(
      content: contentBuilder.toString(),
      plainText: plainTextBuilder.toString().trim(),
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumber,
      chapterTitle: chapterTitle,
      absolutePageNumber: 0, // Will be set later
    );
  }

  // Estimate the height of an HTML block using approximation
  double _estimateBlockHeight(String html, double maxWidth) {
    final String text = _stripHtmlTags(html);
    if (text.isEmpty) return 0;

    // Get the HTML tag
    String tag = 'p';
    final tagMatch = RegExp(r'<([a-zA-Z0-9]+)[^>]*>').firstMatch(html);
    if (tagMatch != null) {
      tag = tagMatch.group(1)?.toLowerCase() ?? 'p';
    }

    // Set base font size based on tag type
    double fontSize = _fontSize;
    double lineHeight = LINE_HEIGHT_MULTIPLIER;
    double topMargin = 0;
    double bottomMargin = 0;
    double characterWidthFactor =
        0.6; // Average character width as fraction of fontSize

    // Extra safety factor for complex content that might need more space
    double safetyFactor = 1.0;

    // Check if we have an image tag - images need special handling
    if (html.contains('<img')) {
      // Images typically need more space - rough estimation
      return _effectiveViewportHeight * 0.6; // Assume image takes 60% of page
    }

    // Adjust sizing based on tag type
    if (tag.startsWith('h')) {
      // Heading tags
      int level = int.tryParse(tag.substring(1)) ?? 1;
      fontSize =
          _fontSize * (2.5 - (level * 0.3)); // h1 is largest, then scales down
      bottomMargin = 0.5 * fontSize;
      topMargin = 0.6 * fontSize; // Increased top margin for headings
      characterWidthFactor = 0.7; // Headers often use wider font

      // Headings might need more vertical space especially with line wrapping
      safetyFactor = 1.2; // Increased from 1.18

      // If this is just a chapter number (1, 2, etc.), give it more space
      if (text.trim().length <= 3 && RegExp(r'^\d+$').hasMatch(text.trim())) {
        // This is likely just a chapter number
        safetyFactor = 1.25;
        topMargin = 1.0 * fontSize;
        bottomMargin = 1.0 * fontSize;
      }
    } else if (tag == 'p') {
      // Paragraph
      bottomMargin = 0.5 * fontSize;

      // Check for styles that affect layout
      if (html.contains('text-align: center') ||
          html.contains('text-align:center')) {
        characterWidthFactor =
            0.65; // Centered text often has different spacing
      }
      if (html.contains('text-indent')) {
        // Account for indentation space
        topMargin += 0.2 * fontSize;
      }

      // Calculate complexity of text - complex paragraphs need more space
      if (text.length > 500) {
        safetyFactor = 1.1; // Increased from 1.08
      }

      // Check for content with lots of punctuation or special characters
      final punctuationRatio =
          RegExp(r'''[,.;:!?"\'\-]''').allMatches(text).length / text.length;
      if (punctuationRatio > 0.15) {
        safetyFactor = math.max(safetyFactor, 1.12); // Increased from 1.1
      }

      // Check for dialog-heavy content (quotes or multiple short paragraphs)
      // Dialog often has unexpected rendering behavior and needs more space
      if (text.contains('"') || text.contains('"') || text.contains("said")) {
        safetyFactor = math.max(safetyFactor, 1.15); // Increased from 1.12
      }

      // Additional check for paragraph starts with quotation (likely dialog)
      if (text.trim().startsWith('"') || text.trim().startsWith('"')) {
        safetyFactor = math.max(safetyFactor, 1.18); // Increased from 1.15
        // Add a bit more margin for dialog
        topMargin += 0.2 * fontSize; // Increased from 0.15
      }

      // Check for content with potentially wider characters
      if (RegExp(r'[MWQO]').hasMatch(text)) {
        characterWidthFactor = 0.65; // Adjust for wider characters
      }

      // Check for very long words that might cause wrapping issues
      final words = text.split(RegExp(r'\s+'));
      final maxWordLength =
          words.fold(0, (max, word) => math.max(max, word.length));
      if (maxWordLength > 15) {
        // Long words can cause unexpected wrapping
        safetyFactor = math.max(safetyFactor, 1.12); // Increased from 1.1
      }

      // Short paragraphs often take more space than calculated (due to min height in rendering)
      if (text.length < 100) {
        safetyFactor = math.max(safetyFactor, 1.12); // Increased from 1.1
      }
    } else if (tag == 'blockquote') {
      // Blockquote
      bottomMargin = 0.5 * fontSize;
      topMargin = 0.5 * fontSize;
      // Account for margin/padding in blockquotes
      maxWidth = maxWidth * 0.9;
      safetyFactor = 1.18; // Increased from 1.15
    } else if (tag == 'pre') {
      // Preformatted text
      lineHeight = 1.2; // Tighter line height for code
      characterWidthFactor = 0.5; // Monospace fonts are often narrower
      safetyFactor = 1.18; // Increased from 1.15
    } else if (tag == 'ul' || tag == 'ol') {
      // Lists
      bottomMargin = 0.5 * fontSize;
      // Account for list item indentation
      maxWidth = maxWidth * 0.9;
      safetyFactor = 1.22; // Increased from 1.2
    }

    // Calculate number of lines needed with improved accuracy
    // Take into account that some characters are wider than others
    final charsPerLine = (maxWidth / (fontSize * characterWidthFactor)).floor();

    // Handle texts with long words better
    int numLines = 0;

    // Analyze word lengths to better estimate wrapping
    final words = text.split(RegExp(r'\s+'));
    int remainingLineChars = charsPerLine;

    for (final word in words) {
      if (word.isEmpty) continue;

      // Check if this word fits on the current line
      if (word.length <= remainingLineChars) {
        remainingLineChars -= word.length + 1; // word + space
      } else {
        // Word doesn't fit, start a new line
        numLines++;

        if (word.length > charsPerLine) {
          // Very long word that needs multiple lines
          numLines += (word.length / charsPerLine).ceil() - 1;
          remainingLineChars = charsPerLine - (word.length % charsPerLine);
          if (remainingLineChars == charsPerLine) remainingLineChars = 0;
        } else {
          remainingLineChars = charsPerLine - word.length - 1;
        }
      }
    }

    // Add one more line if we've started filling a line
    if (remainingLineChars < charsPerLine) {
      numLines++;
    }

    // Ensure at least one line
    numLines = math.max(1, numLines);

    // Quotation marks and punctuation often cause unexpected wrapping
    // Add a small line count adjustment based on punctuation density
    final quoteCount = '"\''
        .split('')
        .fold(0, (count, char) => count + text.split(char).length - 1);
    if (quoteCount > 0) {
      // Add a small percentage of extra lines based on quote count
      numLines += (numLines * 0.06 * math.min(quoteCount, 5))
          .ceil(); // Increased from 0.05
    }

    // Calculate total height with safety factor
    final calculatedHeight =
        topMargin + (numLines * fontSize * lineHeight) + bottomMargin;
    return calculatedHeight * safetyFactor;
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

    // Enhance paragraph styling with indentation, justification and margins
    // Use text-justify: inter-word to ensure proper word spacing in justified text
    content = content.replaceAll('<p>',
        '<p style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">');

    // Enhance heading styling
    content = content.replaceAll('<h1>',
        '<h1 style="text-align: center; font-weight: bold; margin-top: 1em; margin-bottom: 0.8em;">');
    content = content.replaceAll('<h2>',
        '<h2 style="text-align: center; font-weight: bold; margin-top: 1em; margin-bottom: 0.8em;">');
    content = content.replaceAll('<h3>',
        '<h3 style="font-weight: bold; margin-top: 1em; margin-bottom: 0.5em;">');

    // Make sure emphasis and strong tags have proper styling
    content = content.replaceAll('<i>', '<em style="font-style: italic;">');
    content = content.replaceAll('</i>', '</em>');
    content = content.replaceAll('<b>', '<strong style="font-weight: bold;">');
    content = content.replaceAll('</b>', '</strong>');

    // Enhance blockquote and other common elements
    content = content.replaceAll('<blockquote>',
        '<blockquote style="margin-left: 2em; font-style: italic;">');

    // Remove explicit line breaks that might cause formatting issues
    content = content.replaceAll('<br>', ' ');
    content = content.replaceAll('<br/>', ' ');
    content = content.replaceAll('<BR>', ' ');

    // Clean up whitespace inside elements to prevent unnecessary line breaks
    content = content.replaceAll(RegExp(r'>\s+<'), '><');

    // Special handling for dialog - ensure proper spacing and indentation
    // This pattern matches quoted dialog with specific styling
    if (content.contains('"') || content.contains('"')) {
      // Standardize quotes for consistency
      content = content.replaceAll('"', '"').replaceAll('"', '"');

      // Look for dialog patterns and apply special formatting
      final plainText = _stripHtmlTags(content);
      if (!content.contains('<p') && plainText.startsWith('"')) {
        // This is likely raw dialog text - format it properly
        return _formatDialogParagraph(content);
      }
    }

    // Finally, add a wrapper that ensures block-level formatting is applied correctly
    if (!content.trim().startsWith('<')) {
      // Plain text - wrap in paragraph with proper justification
      content =
          '<p style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">${content.trim()}</p>';
    }

    return content;
  }

  // Handle dialog formatting specifically
  String _formatDialogParagraph(String text) {
    final plainText = _stripHtmlTags(text).trim();
    bool isDialogStart = plainText.startsWith('"') || plainText.startsWith('"');

    // For dialog starting with a quotation mark, we want proper indentation
    if (isDialogStart) {
      return '<p style="text-indent: 1.5em; margin-top: 0.8em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">${plainText}</p>';
    }

    // For dialog response (like "Yeah." or short responses)
    if (plainText.length < 100 &&
        (plainText.contains('"') ||
            plainText.contains('said') ||
            plainText.contains('asked'))) {
      return '<p style="text-indent: 1.5em; margin-top: 0.8em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">${plainText}</p>';
    }

    // Regular paragraph
    return '<p style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">${plainText}</p>';
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
        // Add a space after closing tags to prevent words running together
        buffer.write(' ');
        continue;
      }

      if (!inTag) {
        buffer.write(char);
      }
    }

    // Clean up multiple spaces that might have been introduced
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
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
