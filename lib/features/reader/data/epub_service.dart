import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
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
  static const double LINE_HEIGHT_MULTIPLIER = 1.1;
  static const double PAGE_PADDING = 20.0;
  static const double PAGE_TOP_PADDING =
      35.0; // Added specific top padding for app bar
  static const double PAGE_HEIGHT_FRACTION =
      0.98; // Increased from 0.95 to use more of the page height
  static const double SAFETY_MARGIN =
      5.0; // Reduced from 10.0 to allow more content
  static const double LINE_BREAK_FACTOR = 0.98;
  static const double ADDITIONAL_SAFETY_MARGIN = 5.0; // Reduced from 10.0

  // Make these non-late final fields regular fields since we'll update them
  final double _viewportWidth;
  final double _viewportHeight;
  double _fontSize;
  final double _effectiveViewportHeight;
  // Debug flag for tracking page calculations
  final bool _debugMode = false;
  // Text measurer for accurate height calculations
  late final HtmlTextMeasurer _textMeasurer;

  EpubPageCalculator({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = DEFAULT_FONT_SIZE,
  })  : _viewportWidth = viewportWidth - (PAGE_PADDING * 2),
        _viewportHeight = viewportHeight * PAGE_HEIGHT_FRACTION,
        _fontSize = fontSize,
        _effectiveViewportHeight = (viewportHeight * PAGE_HEIGHT_FRACTION) -
            (PAGE_PADDING + PAGE_TOP_PADDING) -
            SAFETY_MARGIN {
    // Initialize text measurer
    _textMeasurer = HtmlTextMeasurer(
        fontSize: _fontSize,
        maxWidth: _viewportWidth,
        maxHeight: _effectiveViewportHeight,
        lineHeight: LINE_HEIGHT_MULTIPLIER);
  }

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

    // 2. Calculate pages using a simplified algorithm with consistent target height
    // The revised pagination algorithm uses a consistent target fill ratio
    // and fewer special case adjustments, providing more predictable pagination
    final List<EpubPage> pages = _paginateHtmlBlocks(blocks, chapterIndex,
        chapterTitle, _viewportWidth, _effectiveViewportHeight);

    // 3. Post-process pages to merge very short pages with the next page when possible
    final List<EpubPage> optimizedPages =
        _mergeShortPages(pages, chapterIndex, chapterTitle);

    if (_debugMode) {
      print(
          'Chapter $chapterIndex paginated in ${stopwatch.elapsedMilliseconds}ms, created ${optimizedPages.length} pages');
    }

    return optimizedPages;
  }

  /// Extract content blocks from HTML - improved version
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

      // NUCLEAR OPTION: Remove all headings from the HTML
      // This prevents duplicate headings completely - we'll add our own chapter title
      bodyContent = bodyContent.replaceAll(
          RegExp(r'<h[1-6][^>]*>.*?</h[1-6]>', dotAll: true), '');

      // Also remove empty paragraphs that might create spacing
      bodyContent = bodyContent.replaceAll(
          RegExp(r'<p[^>]*>(\s|&nbsp;)*</p>', dotAll: true), '');

      // Remove unnecessary line breaks that might cause spacing issues
      bodyContent = bodyContent.replaceAll('<br>', '');
      bodyContent = bodyContent.replaceAll('<br/>', '');
      bodyContent = bodyContent.replaceAll('<BR>', '');

      // Find all block-level elements
      final blockRegex = RegExp(
        r'<(p|div|blockquote|pre|ul|ol|table|figure)[^>]*>(.*?)</\1>',
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
    // Constants for simplified pagination - slightly more conservative
    const double targetFillRatio = 1;
    final double targetHeight = maxHeight * targetFillRatio;

    final List<EpubPage> pages = [];
    final List<ContentBlock> currentPageBlocks = [];
    double currentPageHeight = 0;
    int pageNumber = 1;

    // Always add our own chapter title and set hasChapterTitle flag
    // Since we've removed all headings from the HTML in _extractContentBlocks
    final chapterTitleBlock = ContentBlock(
        text:
            '<h1 style="text-align: center; font-weight: bold; font-size: 105%; margin-bottom: 0; margin-top: 0;">${chapterTitle.trim()}</h1>',
        tag: 'h1',
        isHtml: true);

    // Estimate the height of the title with zero margins
    final titleHeight =
        _estimateBlockHeight('<h1>${chapterTitle.trim()}</h1>', maxWidth) * 0.7;

    // Don't add the title yet - check if we can fit title + first block together
    bool hasChapterTitle = false;

    // Only add blocks if there are blocks to process
    if (blocks.isNotEmpty) {
      // Check if we can fit the title and first block together
      final firstBlock = blocks[0];
      final firstBlockHeight = _estimateBlockHeight(firstBlock.text, maxWidth);

      // If title + first block fit with a slight overage allowance (5% extra),
      // add both at once to prevent a lonely title page
      if (titleHeight + firstBlockHeight <= targetHeight * 1.05) {
        currentPageBlocks.add(chapterTitleBlock);
        currentPageBlocks.add(firstBlock);
        currentPageHeight = titleHeight + firstBlockHeight;
        hasChapterTitle = true;
      } else if (firstBlockHeight > targetHeight * 0.75) {
        // If the first block is very large (>75% of page), add title alone
        // This avoids pushing large first blocks to a second page
        currentPageBlocks.add(chapterTitleBlock);
        currentPageHeight = titleHeight;
        hasChapterTitle = true;
      } else {
        // In this case, we'll put both title and block on next page
        // First create an empty page, then start with title+block
        pages.add(_createPageFromBlocks(
            currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
        currentPageBlocks.clear();
        currentPageBlocks.add(chapterTitleBlock);
        currentPageBlocks.add(firstBlock);
        currentPageHeight = titleHeight + firstBlockHeight;
        hasChapterTitle = true;
      }

      // Start processing from the second block
      for (int i = 1; i < blocks.length; i++) {
        var block = blocks[i];

        // Skip empty paragraphs that might create unwanted gaps
        if (block.tag == 'p') {
          final trimmedText = _stripHtmlTags(block.text).trim();
          if (trimmedText.isEmpty || trimmedText == "&nbsp;") {
            continue;
          }
        }

        // Extract plain text for simple content analysis
        final plainText = _stripHtmlTags(block.text);

        // Simple content type detection (minimal special casing)
        bool isDialog = plainText.trim().startsWith('"') ||
            plainText.trim().startsWith('"');
        bool isChapterNumber = plainText.trim().length <= 3 &&
            RegExp(r'^\d+$').hasMatch(plainText.trim());

        // Apply minimal styling for dialog paragraphs
        if (isDialog &&
            block.tag == 'p' &&
            !block.text.contains('margin-top')) {
          final dialogWithSpace =
              '<p style="text-indent: 1.5em; margin-top: 0.8em; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.3;">$plainText</p>';
          block = ContentBlock(text: dialogWithSpace, tag: 'p', isHtml: true);
        }

        // Apply minimal styling for chapter numbers
        if (isChapterNumber && !block.text.contains('text-align: center')) {
          final chapterNumberBlock = ContentBlock(
              text:
                  '<h1 style="text-align: center; font-weight: bold; margin-top: 1.5em; margin-bottom: 1.5em;">${plainText.trim()}</h1>',
              tag: 'h1',
              isHtml: true);
          block = chapterNumberBlock;
        }

        // Force chapter numbers to start on a new page if there's already content
        if (isChapterNumber && currentPageBlocks.isNotEmpty) {
          pages.add(_createPageFromBlocks(
              currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
          currentPageBlocks.clear();
          currentPageBlocks.add(block);
          currentPageHeight = _estimateBlockHeight(block.text, maxWidth);
          continue;
        }

        // Estimate block height (simple, without complex adjustments)
        final blockHeight = _estimateBlockHeight(block.text, maxWidth);

        // Check if block is too large for a single page
        if (blockHeight > maxHeight * 0.95) {
          // Split very large blocks across multiple pages
          if (currentPageBlocks.isNotEmpty) {
            // Create a page with current blocks first
            pages.add(_createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
            currentPageBlocks.clear();
            currentPageHeight = 0;
          }

          // Split the large block
          _splitAndAddLargeBlock(block, maxWidth, maxHeight, chapterIndex,
              chapterTitle, pageNumber, pages);

          // Update page number
          pageNumber += (blockHeight / maxHeight).ceil();
          continue;
        }

        // Standard case: check if this block fits on the current page
        if (currentPageHeight + blockHeight <= targetHeight) {
          // Block fits within our target height
          currentPageBlocks.add(block);
          currentPageHeight += blockHeight;
        } else if (block.tag == 'p' &&
            !block.text.contains('<img') &&
            currentPageHeight >= targetHeight * 0.5) {
          // Current page is at least 50% filled and this paragraph would overflow
          // Try to split the paragraph to better fill the page
          final remainingHeight = targetHeight - currentPageHeight;

          // Use a more conservative fill ratio for splitting - REDUCED from 0.95
          const double splitFillRatio = 0.95;

          final splitResult = _splitParagraphBlock(
              block, maxWidth, remainingHeight, splitFillRatio);

          if (splitResult.firstPart.isNotEmpty) {
            // Check if second part is too short - don't split if it would create a tiny second part
            final secondPartHeight =
                _estimateBlockHeight(splitResult.secondPart, maxWidth);

            // If second part would create a very short page (<20% of page height), don't split
            if (secondPartHeight < maxHeight * 0.2) {
              // Just put the whole paragraph on the next page
              pages.add(_createPageFromBlocks(
                  currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
              currentPageBlocks.clear();
              currentPageBlocks.add(block);
              currentPageHeight = blockHeight;
            } else {
              // Add the first part to the current page
              currentPageBlocks.add(ContentBlock(
                  text: splitResult.firstPart, tag: 'p', isHtml: true));

              // Create the page
              pages.add(_createPageFromBlocks(
                  currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));

              // Start new page with the second part
              currentPageBlocks.clear();
              currentPageHeight = 0;

              if (splitResult.secondPart.isNotEmpty) {
                // Add second part to new page
                currentPageBlocks.add(ContentBlock(
                    text: splitResult.secondPart, tag: 'p', isHtml: true));
                currentPageHeight =
                    _estimateBlockHeight(splitResult.secondPart, maxWidth);
              }
            }
          } else {
            // Could not split effectively - create page with current blocks
            pages.add(_createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));

            // Start a new page with this block
            currentPageBlocks.clear();
            currentPageBlocks.add(block);
            currentPageHeight = blockHeight;
          }
        } else {
          // Block doesn't fit and we can't/shouldn't split it
          // Create a page with current blocks if there are any
          if (currentPageBlocks.isNotEmpty) {
            pages.add(_createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber++, chapterTitle));
          }

          // Start a new page with this block
          currentPageBlocks.clear();
          currentPageBlocks.add(block);
          currentPageHeight = blockHeight;
        }
      }
    } else {
      // No blocks to process, just add the title
      currentPageBlocks.add(chapterTitleBlock);
      currentPageHeight = titleHeight;
      hasChapterTitle = true;
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
    // Special case for images or non-text content
    if (block.text.contains('<img') || block.tag == 'figure') {
      // Put images on their own page
      pages.add(EpubPage(
          content: block.text,
          plainText: _stripHtmlTags(block.text),
          chapterIndex: chapterIndex,
          pageNumberInChapter: startPageNumber,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0));
      return;
    }

    // Handle text blocks by finding natural split points
    if (block.tag == 'p' || block.tag == 'div' || block.tag == 'span') {
      final String text = _stripHtmlTags(block.text);
      if (text.length < 200) {
        // If not very long, just keep it on one page
        pages.add(EpubPage(
            content: block.text,
            plainText: text,
            chapterIndex: chapterIndex,
            pageNumberInChapter: startPageNumber,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0));
        return;
      }

      // Extract the original style if available
      String style = '';
      if (block.tag == 'p') {
        final styleMatch =
            RegExp(r'''style=["'](.*?)["']''').firstMatch(block.text);
        if (styleMatch != null) {
          style = styleMatch.group(1) ?? '';
        }
        if (style.isEmpty) {
          style =
              "text-indent: 1.5em; margin-bottom: 0.5em; text-align: justify; text-justify: inter-word;";
        }
      }

      // Estimate approximate characters per page
      final approxCharsPerLine = (maxWidth / (_fontSize * 0.6)).floor();
      final approxLinesPerPage =
          (maxHeight / (_fontSize * LINE_HEIGHT_MULTIPLIER)).floor();
      final charsPerPage = (approxCharsPerLine * approxLinesPerPage * 0.85)
          .floor(); // 85% fill ratio

      // Use natural break points for splitting
      final segments = _splitTextIntoPages(text, charsPerPage);

      // Create pages for each segment
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final htmlContent = block.tag == 'p'
            ? '<p style="$style">${segment.trim()}</p>'
            : '<${block.tag}>${segment.trim()}</${block.tag}>';

        pages.add(EpubPage(
            content: htmlContent,
            plainText: segment,
            chapterIndex: chapterIndex,
            pageNumberInChapter: startPageNumber + i,
            chapterTitle: chapterTitle,
            absolutePageNumber: 0));
      }
    } else {
      // For non-text blocks, just put on a single page
      pages.add(EpubPage(
          content: block.text,
          plainText: _stripHtmlTags(block.text),
          chapterIndex: chapterIndex,
          pageNumberInChapter: startPageNumber,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0));
    }
  }

  // Split text into pages at natural break points
  List<String> _splitTextIntoPages(String text, int targetCharsPerPage) {
    final List<String> segments = [];
    int startIndex = 0;

    while (startIndex < text.length) {
      // Calculate target end point for this segment
      int endIndex = math.min(startIndex + targetCharsPerPage, text.length);

      // Find optimal break point near target end
      if (endIndex < text.length) {
        endIndex = _findOptimalSplitPoint(text, endIndex);
      }

      // Add segment
      segments.add(text.substring(startIndex, endIndex));

      // Move to next segment
      startIndex = endIndex;
    }

    return segments;
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
    if (fullText.length < 100) {
      // Too short to split effectively
      return _ParagraphSplitResult('', block.text);
    }

    // Extract original paragraph style
    String pStyle =
        'style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word;"';
    final styleMatch =
        RegExp(r'''<p\s+style=["'](.*?)["']''').firstMatch(block.text);
    if (styleMatch != null) {
      pStyle = 'style="${styleMatch.group(1)}"';
    }

    // Estimate characters that would fit in remaining height
    final approxCharsPerLine = (maxWidth / (_fontSize * 0.6)).floor();
    final approxLinesAvailable =
        (remainingHeight / (_fontSize * LINE_HEIGHT_MULTIPLIER)).floor();
    final targetChars =
        (approxCharsPerLine * approxLinesAvailable * fillFactor).floor();

    // Find the best split point
    int breakIndex = _findOptimalSplitPoint(fullText, targetChars);

    // If we can't find a good split point or it's too close to start/end, don't split
    if (breakIndex <= 80 || breakIndex >= fullText.length - 50) {
      return _ParagraphSplitResult('', block.text);
    }

    // Create the first part with the original style
    final firstPart =
        '<p $pStyle>${fullText.substring(0, breakIndex).trim()}</p>';

    // For the second part, check if it needs modified indentation
    String secondPartStyle = pStyle;
    if (breakIndex > 0) {
      // If previous char was end of sentence punctuation, keep indentation
      final char = fullText[breakIndex - 1];
      final isEndOfSentence = char == '.' || char == '?' || char == '!';

      // If not at end of sentence, remove indentation for continuation
      if (!isEndOfSentence) {
        secondPartStyle = pStyle.replaceAll('text-indent: 1.5em;', '');
      }
    }

    // Create the second part
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
      // Important: Don't add any newlines between blocks to avoid extra spacing
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

  // Estimate the height of an HTML block using a simplified approach
  double _estimateBlockHeight(String html, double maxWidth) {
    final String text = _stripHtmlTags(html);
    if (text.isEmpty) return 0;

    // Extract the HTML tag
    String tag = 'p';
    final tagMatch = RegExp(r'<([a-zA-Z0-9]+)[^>]*>').firstMatch(html);
    if (tagMatch != null) {
      tag = tagMatch.group(1)?.toLowerCase() ?? 'p';
    }

    // Special handling for images
    if (html.contains('<img')) {
      // Images use a fixed percentage of the viewport height
      return _effectiveViewportHeight * 0.5;
    }

    // Set base font size and spacing based on tag type
    double fontSize = _fontSize;
    double lineHeightMultiplier = LINE_HEIGHT_MULTIPLIER;
    double topMargin = 0;
    double bottomMargin = 0;
    double characterWidthFactor =
        0.6; // Average character width as fraction of fontSize

    // Simple tag-based adjustments with fewer special cases
    if (tag.startsWith('h')) {
      // Heading tags with size based on level
      int level = int.tryParse(tag.substring(1)) ?? 1;
      fontSize = _fontSize * (2.0 - (level * 0.2));
      topMargin = 0.5 * fontSize;
      bottomMargin = 0.5 * fontSize;
      characterWidthFactor = 0.7; // Headers often use wider font
    } else if (tag == 'p') {
      // Regular paragraphs
      bottomMargin = 0.3 * fontSize;

      // Basic check for centered text
      if (html.contains('text-align: center')) {
        characterWidthFactor = 0.65;
      }

      // Simple check for indentation
      if (html.contains('text-indent')) {
        topMargin += 0.1 * fontSize;
      }
    } else if (tag == 'blockquote') {
      // Blockquotes with margins
      topMargin = 0.4 * fontSize;
      bottomMargin = 0.4 * fontSize;
      maxWidth = maxWidth * 0.9; // Account for indentation
    } else if (tag == 'pre') {
      // Code blocks
      lineHeightMultiplier = 1.2;
      characterWidthFactor = 0.5; // Monospace fonts
    } else if (tag == 'ul' || tag == 'ol') {
      // Lists
      bottomMargin = 0.4 * fontSize;
      maxWidth = maxWidth * 0.9; // Account for list indentation
    }

    // Calculate number of characters per line
    final charsPerLine = (maxWidth / (fontSize * characterWidthFactor)).floor();

    // Calculate number of lines needed (simplified word-based approach)
    int numLines = 0;
    final words = text.split(RegExp(r'\s+'));
    int currentLineLength = 0;

    for (final word in words) {
      // Skip empty words
      if (word.isEmpty) continue;

      // Check if this word fits on current line
      if (currentLineLength + word.length + 1 <= charsPerLine) {
        // Word fits, add it to current line
        currentLineLength += word.length + 1; // word + space
      } else {
        // Word doesn't fit, start a new line
        numLines++;

        if (word.length > charsPerLine) {
          // Very long word that needs multiple lines
          numLines += (word.length / charsPerLine).ceil() - 1;
          currentLineLength = word.length % charsPerLine;
          if (currentLineLength == 0) currentLineLength = charsPerLine;
        } else {
          currentLineLength = word.length;
        }
      }
    }

    // Add final line if there's content in progress
    if (currentLineLength > 0) {
      numLines++;
    }

    // Ensure at least one line
    numLines = math.max(1, numLines);

    // Apply a content-based safety factor with more conservative values
    double safetyFactor = 1.0;

    // Check for specific patterns that might cause overflow
    bool hasComplexFormatting = html.contains('style=') && html.contains(';');
    bool containsQuotes = text.contains('"') || text.contains('"');
    bool isDialog =
        containsQuotes && (text.contains('said') || text.contains('asked'));
    bool hasSpecialChars = text.contains('—') || text.contains('–');
    bool hasNumbers = RegExp(r'\d+').hasMatch(text);

    // Adjust safety factors based on content characteristics
    if (isDialog) {
      safetyFactor = 1.15;
    } else if (hasComplexFormatting) {
      safetyFactor = 1.12; // Complex formatting needs more room
    } else if (containsQuotes) {
      safetyFactor = 1.08; // Just quotes
    } else if (hasSpecialChars) {
      safetyFactor = 1.07; // Special characters
    } else if (hasNumbers) {
      safetyFactor = 1.05; // Numbers might need slightly more space
    } else if (text.length > 500) {
      safetyFactor = 1.05; // Long paragraphs
    } else {
      safetyFactor = 1.02; // Default safety factor is slightly increased
    }

    // Calculate final height
    final height =
        topMargin + (numLines * fontSize * lineHeightMultiplier) + bottomMargin;
    return height * safetyFactor;
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
    // Reduce margins and increase line height slightly to better fill the page
    content = content.replaceAll('<p>',
        '<p style="text-indent: 1.5em; margin-bottom: 0; margin-top: 0; text-align: justify; text-justify: inter-word; line-height: 1.2;">');

    // Enhance heading styling - reduce margins further
    content = content.replaceAll('<h1>',
        '<h1 style="text-align: center; font-weight: bold; margin-top: 0.5em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h2>',
        '<h2 style="text-align: center; font-weight: bold; margin-top: 0.5em; margin-bottom: 0.5em;">');
    content = content.replaceAll('<h3>',
        '<h3 style="font-weight: bold; margin-top: 0.5em; margin-bottom: 0.3em;">');

    // Make sure emphasis and strong tags have proper styling
    content = content.replaceAll('<i>', '<em style="font-style: italic;">');
    content = content.replaceAll('</i>', '</em>');
    content = content.replaceAll('<b>', '<strong style="font-weight: bold;">');
    content = content.replaceAll('</b>', '</strong>');

    // Enhance blockquote and other common elements
    content = content.replaceAll('<blockquote>',
        '<blockquote style="margin-left: 1.5em; margin-right: 1em; font-style: italic; line-height: 1.3; margin-top: 0.3em; margin-bottom: 0.3em;">');

    // Special handling for dialog with quote marks
    bool hasDialogMarkers = content.contains('"') ||
        content.contains('"') ||
        content.contains('"') ||
        content.contains("'") ||
        content.contains("'");

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
          '<p style="text-indent: 1.5em; margin-bottom: 0; margin-top: 0; text-align: justify; text-justify: inter-word; line-height: 1.2;">${content.trim()}</p>';
    }

    return content;
  }

  // Process and enhance image tags for better rendering
  String _processImageTags(String html) {
    if (!html.contains('<img')) {
      return html;
    }

    // Process all img tags to make them responsive
    return html.replaceAllMapped(
      RegExp(r'<img\s+([^>]*)>', caseSensitive: false),
      (match) {
        String attributes = match.group(1) ?? '';
        // Extract src attribute
        final srcMatch =
            RegExp(r'''src=["\'](.*?)["\']''').firstMatch(attributes);
        final src = srcMatch?.group(1) ?? '';

        // If no valid src, return the original tag
        if (src.isEmpty) {
          return match.group(0) ?? '';
        }

        // Style for responsive images with proper alignment
        return '<div style="text-align: center; margin: 1em 0;"><img src="$src" style="max-width: 95%; height: auto; display: inline-block;" alt="Image" /></div>';
      },
    );
  }

  // Check if HTML content contains an image
  bool _containsImage(String html) {
    return html.contains('<img') || html.contains('<figure');
  }

  // Handle a block that's too large to fit on a single page
  void _handleOversizedBlock(
    ContentBlock block,
    List<EpubPage> pages,
    int chapterIndex,
    int pageNumber,
    String chapterTitle,
  ) {
    // For images, put them on their own page
    if (_containsImage(block.text)) {
      pages.add(EpubPage(
        content: block.text,
        plainText: _stripHtmlTags(block.text),
        chapterIndex: chapterIndex,
        pageNumberInChapter: pageNumber,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0, // Will be set later
      ));
      return;
    }

    // For text content, try to split it
    if (block.tag == 'p') {
      // Large paragraph - split it into chunks
      final text = _stripHtmlTags(block.text);
      if (text.isEmpty) return;

      // Get paragraph style if available
      String pStyle =
          'style="text-indent: 1.5em; margin-bottom: 0; text-align: justify; text-justify: inter-word;"';
      final styleMatch =
          RegExp(r'''<p\s+style=["'](.*?)["']''').firstMatch(block.text);
      if (styleMatch != null) {
        pStyle = 'style="${styleMatch.group(1)}"';
      }

      // Split into chunks of approximately 500 characters, trying to break at sentences
      final List<String> chunks = [];
      int startPos = 0;
      while (startPos < text.length) {
        int endPos = startPos + 500;
        if (endPos >= text.length) {
          chunks.add(text.substring(startPos));
          break;
        }

        // Try to find a sentence break (. ! ?) within 100 chars after the target
        int breakPos = -1;
        for (int i = endPos; i < math.min(endPos + 100, text.length); i++) {
          if (i > 0 &&
              (text[i - 1] == '.' ||
                  text[i - 1] == '!' ||
                  text[i - 1] == '?') &&
              text[i] == ' ') {
            breakPos = i;
            break;
          }
        }

        // If no sentence break found, look for other breaks
        if (breakPos == -1) {
          for (int i = endPos; i < math.min(endPos + 100, text.length); i++) {
            if (text[i] == ' ' || text[i] == '\n') {
              breakPos = i;
              break;
            }
          }
        }

        // If still no break found, force a break
        if (breakPos == -1) {
          breakPos = math.min(endPos + 50, text.length);
        }

        chunks.add(text.substring(startPos, breakPos));
        startPos = breakPos;
      }

      // Create pages for each chunk
      for (int i = 0; i < chunks.length; i++) {
        final chunkHtml = '<p $pStyle>${chunks[i]}</p>';
        pages.add(EpubPage(
          content: chunkHtml,
          plainText: chunks[i],
          chapterIndex: chapterIndex,
          pageNumberInChapter: pageNumber + i,
          chapterTitle: chapterTitle,
          absolutePageNumber: 0, // Will be set later
        ));
      }
    } else {
      // For non-paragraph elements, just put on a single page
      pages.add(EpubPage(
        content: block.text,
        plainText: _stripHtmlTags(block.text),
        chapterIndex: chapterIndex,
        pageNumberInChapter: pageNumber,
        chapterTitle: chapterTitle,
        absolutePageNumber: 0, // Will be set later
      ));
    }
  }

  // Helper method to combine HTML blocks into a single HTML string
  String _combineBlocksHtml(List<ContentBlock> blocks) {
    final buffer = StringBuffer();

    // Add a wrapper div for measurement
    buffer.write('<div style="width: ${_viewportWidth}px;">');

    // Add each block
    for (final block in blocks) {
      buffer.write(block.text);
      buffer.write('\n');
    }

    // Close wrapper div
    buffer.write('</div>');

    return buffer.toString();
  }

  // Handle dialog formatting specifically
  String _formatDialogParagraph(String text) {
    final plainText = _stripHtmlTags(text).trim();
    bool isDialogStart = plainText.startsWith('"') || plainText.startsWith('"');

    // For dialog starting with a quotation mark, we want proper indentation
    if (isDialogStart) {
      return '<p style="text-indent: 1.5em; margin-top: 0; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.25;">$plainText</p>';
    }

    // For dialog response (like "Yeah." or short responses)
    if (plainText.length < 100 &&
        (plainText.contains('"') ||
            plainText.contains('said') ||
            plainText.contains('asked'))) {
      return '<p style="text-indent: 1.5em; margin-top: 0; margin-bottom: 0; text-align: justify; text-justify: inter-word; line-height: 1.25;">$plainText</p>';
    }

    // Regular paragraph
    return '<p style="text-indent: 1.5em; margin-bottom: 0; margin-top: 0; text-align: justify; text-justify: inter-word; line-height: 1.2;">$plainText</p>';
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

  // New method for text painter-based pagination
  Future<List<EpubPage>> _paginateBlocksWithTextPainter(
    List<ContentBlock> blocks,
    int chapterIndex,
    String chapterTitle,
  ) async {
    final List<EpubPage> pages = [];
    final List<ContentBlock> currentPageBlocks = [];
    int pageNumber = 1;
    bool debugEnabled = false; // Set to true to enable debug output

    // Constants for page filling logic - adjusted for better utilization
    const double minPageFillRatio = 0.45; // Increased minimum fill ratio
    const double maxPageFillRatio = 0.92; // Increased maximum fill ratio

    // Add chapter title as inline content, more constrained
    if (chapterTitle.isNotEmpty) {
      // Smaller, more compact chapter title
      currentPageBlocks.add(ContentBlock(
        text:
            '<h1 style="text-align: center; font-weight: bold; font-size: 105%; margin-bottom: 0.2em; margin-top: 0.2em;">${chapterTitle.trim()}</h1>',
        tag: 'h1',
        isHtml: true,
      ));
    }

    // Process blocks sequentially with lookahead
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // Skip chapter title blocks since we already added our own
      if (block.tag.startsWith('h') &&
          _stripHtmlTags(block.text).trim() == chapterTitle.trim()) {
        continue;
      }

      // Build HTML for current blocks plus this new block
      String currentPageHtml =
          _combineBlocksHtml([...currentPageBlocks, block]);

      // Calculate current page height with new block
      final estimatedHeight = _textMeasurer.calculateHeight(currentPageHtml);
      final maxSafeHeight = _effectiveViewportHeight * maxPageFillRatio;

      // Check if this content fits on the page
      if (estimatedHeight <= maxSafeHeight) {
        // Content fits, add the block to current page
        currentPageBlocks.add(block);

        // Look ahead to next block to see if adding it would overflow
        // This helps prevent orphaned headings and single lines
        if (i < blocks.length - 1) {
          final nextBlock = blocks[i + 1];
          final nextPageHtml =
              _combineBlocksHtml([...currentPageBlocks, nextBlock]);
          final nextEstimatedHeight =
              _textMeasurer.calculateHeight(nextPageHtml);

          // If next block would overflow and current page is reasonably filled,
          // go ahead and create the page now
          if (nextEstimatedHeight > maxSafeHeight &&
              estimatedHeight >= _effectiveViewportHeight * minPageFillRatio) {
            // Current page is sufficiently filled and next block won't fit
            final newPage = _createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber, chapterTitle);
            pages.add(newPage);
            pageNumber++;
            currentPageBlocks.clear();
          }
        }
      } else if (currentPageBlocks.isEmpty) {
        // Single block too large for a page, needs to be split
        _handleOversizedBlock(
            block, pages, chapterIndex, pageNumber, chapterTitle);
        pageNumber++;
      } else {
        // Content doesn't fit, check if we should try to split
        bool shouldTrySplit = true;

        // For heavy dialog content, avoid splitting
        if (block.text.contains('"') || block.text.contains("'")) {
          shouldTrySplit = false;
        }

        // Only try to split paragraphs, not headings, lists, etc.
        if (shouldTrySplit && block.tag == 'p' && !_containsImage(block.text)) {
          // Get the content of the block to split
          final contentToSplit = block.text;

          // Try to split the content
          final splitResult = _textMeasurer.splitContentForPage(contentToSplit);

          if (splitResult.firstPart.isNotEmpty &&
              splitResult.secondPart.isNotEmpty &&
              _stripHtmlTags(splitResult.firstPart).length >= 25) {
            // Increased from 20 to ensure chunks aren't too small

            // Add the first part to the current page
            currentPageBlocks.add(ContentBlock(
                text: splitResult.firstPart, tag: 'p', isHtml: true));

            // Create a page with the current blocks
            final newPage = _createPageFromBlocks(
                currentPageBlocks, chapterIndex, pageNumber, chapterTitle);
            pages.add(newPage);
            pageNumber++;

            // Start next page with the second part
            currentPageBlocks.clear();
            currentPageBlocks.add(ContentBlock(
                text: splitResult.secondPart, tag: 'p', isHtml: true));

            continue;
          }
        }

        // If we couldn't split, create a page with current blocks
        final newPage = _createPageFromBlocks(
            currentPageBlocks, chapterIndex, pageNumber, chapterTitle);
        pages.add(newPage);
        pageNumber++;

        // Start next page with this block
        currentPageBlocks.clear();
        currentPageBlocks.add(block);
      }
    }

    // Add the final page if there are remaining blocks
    if (currentPageBlocks.isNotEmpty) {
      final finalPage = _createPageFromBlocks(
          currentPageBlocks, chapterIndex, pageNumber, chapterTitle);
      pages.add(finalPage);
    }

    return pages;
  }

  // Helper method to normalize text for comparison
  String _normalizeText(String text) {
    // Remove extra spaces, convert to lowercase, and normalize Roman numerals
    String normalized = text.trim().toLowerCase();

    // Replace special characters and normalize whitespace
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Replace Roman numerals with their standard form (if they exist)
    final romanNumeralPattern =
        RegExp(r'\b(i{1,3}|iv|v|vi{1,3}|ix|x)\b', caseSensitive: false);
    normalized = normalized.replaceAllMapped(romanNumeralPattern, (match) {
      final numeral = match.group(0)?.toLowerCase() ?? '';
      return ' $numeral '; // Add spaces to ensure matching as whole words
    });

    return normalized.trim();
  }

  // Helper method to check if headings share numeric parts
  // For example, "Chapter 1" and "1" share "1"; "1.1" and "1" share "1"
  bool _headingsShareNumericParts(String heading1, String heading2) {
    // Extract numeric parts from both headings
    final numRegExp = RegExp(r'\d+(\.\d+)?');
    final nums1 =
        numRegExp.allMatches(heading1).map((m) => m.group(0) ?? '').toList();
    final nums2 =
        numRegExp.allMatches(heading2).map((m) => m.group(0) ?? '').toList();

    if (nums1.isEmpty || nums2.isEmpty) return false;

    // Check if any number from heading1 contains or is contained by any number from heading2
    for (final num1 in nums1) {
      for (final num2 in nums2) {
        // Check exact match
        if (num1 == num2) return true;

        // Check if one is part of the other (e.g., "1" is part of "1.1")
        if (num1.startsWith(num2) || num2.startsWith(num1)) return true;
      }
    }

    return false;
  }

  // Post-process pages to merge very short pages with the next page
  List<EpubPage> _mergeShortPages(
      List<EpubPage> pages, int chapterIndex, String chapterTitle) {
    // If there are fewer than 2 pages, no merging needed
    if (pages.length < 2) return pages;

    final List<EpubPage> result = [];
    int i = 0;

    while (i < pages.length) {
      // Get current page
      final currentPage = pages[i];

      // Check if this is a short page (less than 25% of viewport height)
      final double currentPageHeight =
          _estimateBlockHeight(currentPage.content, _viewportWidth);
      final bool isShortPage =
          currentPageHeight < (_effectiveViewportHeight * 0.35);

      // Skip merging if this is the last page or if it's not a short page
      if (!isShortPage || i == pages.length - 1) {
        result.add(currentPage);
        i++;
        continue;
      }

      // Check if merging with next page would fit
      final nextPage = pages[i + 1];
      final double nextPageHeight =
          _estimateBlockHeight(nextPage.content, _viewportWidth);

      // If combined height is acceptable (with a small buffer), merge the pages
      if (currentPageHeight + nextPageHeight <=
          _effectiveViewportHeight * 1.05) {
        // Merge the content
        final mergedContent = currentPage.content + nextPage.content;
        final mergedPlainText =
            '${currentPage.plainText} ${nextPage.plainText}';

        // Create merged page
        final mergedPage = EpubPage(
          content: mergedContent,
          plainText: mergedPlainText,
          chapterIndex: chapterIndex,
          pageNumberInChapter: currentPage.pageNumberInChapter,
          chapterTitle: chapterTitle,
          absolutePageNumber: currentPage.absolutePageNumber,
        );

        // Add merged page to result
        result.add(mergedPage);

        // Skip the next page since we merged it
        i += 2;
      } else {
        // Couldn't merge, add current page as-is
        result.add(currentPage);
        i++;
      }
    }

    // Recalculate page numbers in chapter
    for (int j = 0; j < result.length; j++) {
      result[j] = EpubPage(
        content: result[j].content,
        plainText: result[j].plainText,
        chapterIndex: chapterIndex,
        pageNumberInChapter: j + 1,
        chapterTitle: chapterTitle,
        absolutePageNumber: result[j].absolutePageNumber,
      );
    }

    return result;
  }
}

/// Class to measure HTML text height using approximate calculations
class HtmlTextMeasurer {
  final double fontSize;
  final double maxWidth;
  final double maxHeight;
  final double lineHeight;
  final LRUCache<String, double> _heightCache = LRUCache<String, double>(100);

  HtmlTextMeasurer({
    required this.fontSize,
    required this.maxWidth,
    required this.maxHeight,
    required this.lineHeight,
  });

  /// Calculate the approximate height of HTML content
  double calculateHeight(String html) {
    // Check cache first
    final cacheResult = _heightCache.get(html);
    if (cacheResult != null) {
      return cacheResult;
    }

    // Strip HTML to get text for basic calculation
    final text = _stripHtml(html);
    if (text.isEmpty) return 0;

    // Basic height calculation
    double estimatedHeight = 0;

    // Apply different safety factors based on content type
    double safetyFactor = 1.0;

    // Check for images
    if (html.contains('<img') || html.contains('<figure')) {
      // Images need more space
      estimatedHeight = maxHeight * 0.6;
      _heightCache.put(html, estimatedHeight);
      return estimatedHeight;
    }

    // Check for content type
    final bool isHeading =
        html.contains('<h1') || html.contains('<h2') || html.contains('<h3');
    final bool isDialog =
        html.contains('"') || html.contains('"') || html.contains('said');

    // Adjust for content type
    if (isHeading) {
      safetyFactor = 1.3; // Headings need more space
    } else if (isDialog) {
      safetyFactor = 1.25; // Dialog needs more space
    } else if (text.length > 500) {
      safetyFactor = 1.15; // Long paragraphs need more space
    } else {
      safetyFactor = 1.1; // Default safety factor
    }

    // Calculate character-based height
    final charactersPerLine = (maxWidth / (fontSize * 0.6)).floor();
    int lines = (text.length / charactersPerLine).ceil();

    // Account for line breaks and word wrapping
    lines += (text.split(' ').length / 15)
        .floor(); // Assume each 15 words might create an additional line wrap

    // Calculate height with line height and safety factor
    estimatedHeight =
        (lines * fontSize * lineHeight + (fontSize * 0.8)) * safetyFactor;

    // Cache the result
    _heightCache.put(html, estimatedHeight);

    return estimatedHeight;
  }

  /// Check if content fits within the available height
  bool contentFits(String html) {
    // More aggressive approach - use 90% of max height instead of 80%
    return calculateHeight(html) <= maxHeight;
  }

  /// Split content into first and second part for pagination
  _ParagraphSplitResult splitContentForPage(String html) {
    // Extract text without tags
    final text = _stripHtml(html);
    if (text.length < 100) {
      // Too short to split
      return _ParagraphSplitResult(html, '');
    }

    // Start with 50% of content
    int splitRatio = 50;

    // Determine optimal ratio based on content type
    if (html.contains('"') || html.contains('"')) {
      // For dialog, be more conservative
      splitRatio = 40;
    } else if (text.length > 1000) {
      // For very long paragraphs, be more aggressive
      splitRatio = 60;
    }

    // Calculate initial split point
    int splitPoint = (text.length * splitRatio / 100).round();

    // Find the best place to split (sentence end, comma, or space)
    int bestSplitPoint = _findOptimalSplitPoint(text, splitPoint);

    // Get the style from the original HTML
    String style =
        'style="text-indent: 1.5em; margin-bottom: 0; text-align: justify;"';
    final styleMatch = RegExp(r'''<p\s+style=["'](.*?)["']''').firstMatch(html);
    if (styleMatch != null) {
      style = 'style="${styleMatch.group(1)}"';
    }

    // Create HTML for first and second part
    final firstPart =
        '<p $style>${text.substring(0, bestSplitPoint).trim()}</p>';
    final secondPart = '<p $style>${text.substring(bestSplitPoint).trim()}</p>';

    return _ParagraphSplitResult(firstPart, secondPart);
  }

  // Helper to find the best split point
  int _findOptimalSplitPoint(String text, int targetPoint) {
    // Try to find sentence end within 20% range after target
    final int rangeEnd =
        math.min(text.length, targetPoint + (targetPoint * 0.2).round());

    // Look for sentence end (. ! ?)
    for (int i = targetPoint; i < rangeEnd; i++) {
      if (i > 0 &&
          (text[i - 1] == '.' || text[i - 1] == '!' || text[i - 1] == '?') &&
          (i == text.length - 1 || text[i] == ' ' || text[i] == '\n')) {
        return i;
      }
    }

    // Look for other punctuation (,;:)
    for (int i = targetPoint; i < rangeEnd; i++) {
      if (i > 0 &&
          (text[i - 1] == ',' || text[i - 1] == ';' || text[i - 1] == ':') &&
          (i == text.length - 1 || text[i] == ' ' || text[i] == '\n')) {
        return i;
      }
    }

    // Fall back to space
    for (int i = targetPoint; i < rangeEnd; i++) {
      if (text[i] == ' ' || text[i] == '\n') {
        return i + 1; // Include the space
      }
    }

    // If no good split point, return half of the content
    return targetPoint;
  }

  // Helper to strip HTML tags
  String _stripHtml(String html) {
    final regexp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return html.replaceAll(regexp, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
