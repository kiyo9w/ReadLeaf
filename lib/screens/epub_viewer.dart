import 'dart:io';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:read_leaf/screens/nav_screen.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/widgets/CompanionChat/floating_chat_widget.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:read_leaf/services/thumbnail_service.dart';
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:read_leaf/widgets/floating_selection_menu.dart';
import 'package:read_leaf/widgets/full_selection_menu.dart';
import 'dart:math' as math;
import 'dart:core';

enum EpubLayoutMode { longStrip, vertical, horizontal, facing }

class PageContent {
  final String content;
  final int chapterIndex;
  final int pageNumberInChapter;
  final String chapterTitle;

  PageContent({
    required this.content,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    required this.chapterTitle,
  });
}

class ParsedContent {
  final List<ContentBlock> blocks;
  final Map<String, TextStyle> styles;

  ParsedContent({
    required this.blocks,
    required this.styles,
  });
}

class ContentBlock {
  final TextSpan textSpan;
  final String rawHtml;
  final Map<String, String> styles;

  ContentBlock({
    required this.textSpan,
    required this.rawHtml,
    required this.styles,
  });
}

class EpubPageCalculator {
  static const double DEFAULT_FONT_SIZE = 23.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 32.0;
  static const double PAGE_HEIGHT_FRACTION = 0.835;

  // Font metrics constants
  static const double AVERAGE_CHAR_WIDTH_RATIO = 0.6;
  static const double WORD_SPACING_RATIO = 0.3;
  static const double AVERAGE_WORD_LENGTH = 5.5;

  // Cache structures
  final Map<int, List<PageContent>> _pageCache = {};
  final Map<String, TextStyle> _styleCache = {};

  // Make these non-late final fields regular fields since we'll update them
  final double _viewportWidth;
  final double _viewportHeight;
  double _fontSize;
  final double _effectiveViewportHeight;
  int _wordsPerLine = 0;
  int _linesPerPage = 0;
  int _wordsPerPage = 0;

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
    final availableWidth = _viewportWidth - (PAGE_PADDING * 2);
    final availableHeight = _effectiveViewportHeight - (PAGE_PADDING * 2);

    // Calculate line metrics with exact measurements
    final charWidth = _fontSize * AVERAGE_CHAR_WIDTH_RATIO;
    final wordSpacing = _fontSize * WORD_SPACING_RATIO;
    final averageWordWidth = (charWidth * AVERAGE_WORD_LENGTH) + wordSpacing;
    final lineHeight = _fontSize * LINE_HEIGHT_MULTIPLIER;

    // Calculate maximum words per line (use 98% to account for font variations)
    _wordsPerLine = ((availableWidth / averageWordWidth) * 0.98).floor();

    // Calculate maximum lines per page (use 98% to account for line height variations)
    _linesPerPage = ((availableHeight / lineHeight) * 0.98).floor();

    // Calculate total words per page
    _wordsPerPage = _wordsPerLine * _linesPerPage;

    // Apply device-specific maximum (higher limits than before)
    final deviceConstraints = _getDeviceSpecificConstraints();
    _wordsPerPage = math.min(_wordsPerPage, deviceConstraints);
  }

  int _getDeviceSpecificConstraints() {
    // Base maximum on viewport size with more generous limits
    final viewportArea = _viewportWidth * _viewportHeight;
    final baseMaxWords = (viewportArea / (_fontSize * _fontSize * 1.5))
        .floor(); // Less conservative multiplier

    // Higher limits for each device category
    if (_viewportWidth < 400) {
      // Small phones
      return math.min(baseMaxWords, 250);
    } else if (_viewportWidth < 600) {
      // Regular phones
      return math.min(baseMaxWords, 300);
    } else if (_viewportWidth < 800) {
      // Large phones
      return math.min(baseMaxWords, 350);
    } else {
      // Tablets and larger
      return math.min(baseMaxWords, 400);
    }
  }

  void updateFontSize(double newFontSize) {
    _fontSize = newFontSize;
    _calculateMetrics();
    _pageCache.clear();
    _styleCache.clear();
  }

  // Calculate pages for a chapter
  Future<List<PageContent>> calculatePages(
    String htmlContent,
    int chapterIndex,
    String chapterTitle,
  ) async {
    // Check cache first
    if (_pageCache.containsKey(chapterIndex)) {
      return _pageCache[chapterIndex]!;
    }

    // Parse HTML content
    final parsedContent = await _parseHtmlContent(htmlContent);

    // Calculate page breaks
    final pages =
        _calculatePageBreaks(parsedContent, chapterIndex, chapterTitle);

    // Cache results
    _pageCache[chapterIndex] = pages;
    return pages;
  }

  // Parse HTML content and apply styles
  Future<ParsedContent> _parseHtmlContent(String html) async {
    final styles = <String, TextStyle>{
      'p': TextStyle(
        fontSize: _fontSize,
        height: LINE_HEIGHT_MULTIPLIER,
      ),
      'h1': TextStyle(
        fontSize: _fontSize * 2.0,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      ),
      'h2': TextStyle(
        fontSize: _fontSize * 1.5,
        height: LINE_HEIGHT_MULTIPLIER,
        fontWeight: FontWeight.bold,
      ),
    };

    final blocks = <ContentBlock>[];
    final paragraphs = html.split(RegExp(r'(?=<p>)|(?=<h[1-6]>)'));
    for (var p in paragraphs) {
      if (p.trim().isEmpty) continue;
      String tag = 'p';
      if (p.startsWith('<h1>')) {
        tag = 'h1';
      } else if (p.startsWith('<h2>')) tag = 'h2';

      // Count words in this block
      final plainText = p.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      blocks.add(ContentBlock(
        textSpan: TextSpan(
          text: plainText,
          style: styles[tag],
        ),
        rawHtml: p,
        styles: {'tag': tag},
      ));
    }

    return ParsedContent(blocks: blocks, styles: styles);
  }

  // Measure the height of a block using its TextSpan and available width
  double _measureBlockHeight(ContentBlock block) {
    final textPainter = TextPainter(
      text: block.textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: _viewportWidth);
    return textPainter.height;
  }

  // Improved page break calculation that maximizes content per page
  // New version of page-break calculation that uses actual text measurements
  List<PageContent> _calculatePageBreaks(
      ParsedContent content, int chapterIndex, String chapterTitle) {
    final pages = <PageContent>[];

    // We work with a buffer (for the page's HTML) and a counter for the filled height.
    final StringBuffer currentPageBuffer = StringBuffer();
    double currentPageHeight = 0.0;
    // Our goal is to fill at least 90% of available height.
    final double pageHeightLimit = _effectiveViewportHeight * 0.95;
    // We assume a uniform line height (this could be measured more precisely if needed)
    final double lineHeight = _fontSize * LINE_HEIGHT_MULTIPLIER;
    // Default style for paragraphs:
    final TextStyle defaultStyle =
        TextStyle(fontSize: _fontSize, height: LINE_HEIGHT_MULTIPLIER);
    // Use the full available width (already subtracted in _viewportWidth)
    final double availableWidth = _viewportWidth;

    // Process each block (a block might be a paragraph or header)
    for (final block in content.blocks) {
      // Determine the tag and style (if not set, default to paragraph)
      final String tag = block.styles['tag'] ?? 'p';
      // Use a header style if available; otherwise, use the default style.
      final TextStyle style = content.styles[tag] ?? defaultStyle;

      // For headers, we force a page break.
      if (tag.startsWith('h')) {
        if (currentPageBuffer.isNotEmpty) {
          pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
              pages.length + 1, chapterTitle));
          currentPageBuffer.clear();
          currentPageHeight = 0.0;
        }
        // Write the header (assumed to fit in one line)
        currentPageBuffer.writeln('<$tag>${block.textSpan.text}</$tag>');
        currentPageHeight += lineHeight;
        // Flush if we've reached our height limit.
        if (currentPageHeight >= pageHeightLimit) {
          pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
              pages.length + 1, chapterTitle));
          currentPageBuffer.clear();
          currentPageHeight = 0.0;
        }
        continue;
      }

      // For a normal paragraph:
      final String plainText = block.textSpan.text ?? '';
      // Split the text into words (ignoring extra whitespace)
      final List<String> words = plainText.split(RegExp(r'\s+'));

      String currentLine = "";
      for (final word in words) {
        // Check if this word is wider than availableWidth on its own.
        if (_measureTextWidth(word, style) > availableWidth) {
          // If so, split the word into smaller segments.
          final List<String> segments =
              _splitLongWord(word, style, availableWidth);
          for (final segment in segments) {
            // Process each segment as you would a normal word.
            if (currentLine.isEmpty) {
              currentLine = segment;
            } else {
              final String candidate = '$currentLine $segment';
              if (_measureTextWidth(candidate, style) <= availableWidth) {
                currentLine = candidate;
              } else {
                // Write out the current line.
                currentPageBuffer.writeln(currentLine);
                currentPageHeight += lineHeight;
                // If adding another line would exceed our limit, flush the page.
                if (currentPageHeight + lineHeight > pageHeightLimit) {
                  pages.add(_createPage(currentPageBuffer.toString(),
                      chapterIndex, pages.length + 1, chapterTitle));
                  currentPageBuffer.clear();
                  currentPageHeight = 0.0;
                }
                currentLine = segment;
              }
            }
          }
        } else {
          // Process a normal word.
          if (currentLine.isEmpty) {
            currentLine = word;
          } else {
            final String candidate = '$currentLine $word';
            if (_measureTextWidth(candidate, style) <= availableWidth) {
              currentLine = candidate;
            } else {
              // Write out the current line.
              currentPageBuffer.writeln(currentLine);
              currentPageHeight += lineHeight;
              if (currentPageHeight + lineHeight > pageHeightLimit) {
                pages.add(_createPage(currentPageBuffer.toString(),
                    chapterIndex, pages.length + 1, chapterTitle));
                currentPageBuffer.clear();
                currentPageHeight = 0.0;
              }
              currentLine = word;
            }
          }
        }
      }
      // End of the paragraph: flush any remaining text in the line.
      if (currentLine.isNotEmpty) {
        currentPageBuffer.writeln(currentLine);
        currentPageHeight += lineHeight;
        currentLine = "";
      }
      // Optional: add a small extra gap between paragraphs.
      currentPageBuffer.writeln();
      currentPageHeight += lineHeight * 0.5;

      // If the next line would overflow, flush the page.
      if (currentPageHeight >= pageHeightLimit) {
        pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
            pages.length + 1, chapterTitle));
        currentPageBuffer.clear();
        currentPageHeight = 0.0;
      }
    }

    // Flush any remaining content into a final page.
    if (currentPageBuffer.isNotEmpty) {
      pages.add(_createPage(currentPageBuffer.toString(), chapterIndex,
          pages.length + 1, chapterTitle));
    }

    return pages;
  }

// Helper: measure the width of a text snippet using a given TextStyle.
  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

// Helper: if a word is too wide, split it into segments that each fit the available width.
  List<String> _splitLongWord(
      String word, TextStyle style, double availableWidth) {
    final segments = <String>[];
    String currentSegment = "";
    for (int i = 0; i < word.length; i++) {
      final candidate = currentSegment + word[i];
      if (_measureTextWidth(candidate, style) <= availableWidth) {
        currentSegment = candidate;
      } else {
        if (currentSegment.isEmpty) {
          // In a worst-case scenario, force-add the single character.
          segments.add(word[i]);
        } else {
          segments.add(currentSegment);
          currentSegment = word[i];
        }
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    return segments;
  }

  PageContent _createPage(
      String content, int chapterIndex, int pageNumber, String chapterTitle) {
    return PageContent(
      content: content,
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumber,
      chapterTitle: chapterTitle,
    );
  }

  List<String> _splitTextIntoChunks(String text, int maxChunkSize) {
    final chunks = <String>[];
    int start = 0;

    while (start < text.length) {
      final end = math.min(start + maxChunkSize, text.length);
      chunks.add(text.substring(start, end));
      start = end;
    }

    return chunks;
  }

  // Clear the cache
  void clearCache() {
    _pageCache.clear();
    _styleCache.clear();
  }
}

class EpubPageWidget extends StatelessWidget {
  final PageContent pageContent;
  final bool showTitle;
  final Function(String?)? onSelectionChanged;

  const EpubPageWidget({
    super.key,
    required this.pageContent,
    this.showTitle = false,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: MaterialTextSelectionControls(),
      onSelectionChanged: (selection) {
        onSelectionChanged?.call(selection?.plainText);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[
                Text(
                  pageContent.chapterTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF2F2F7)
                            : const Color(0xFF1C1C1E),
                      ),
                ),
                const SizedBox(height: 24),
              ],
              HtmlWidget(
                pageContent.content,
                textStyle: TextStyle(
                  fontSize: EpubPageCalculator.DEFAULT_FONT_SIZE,
                  height: EpubPageCalculator.LINE_HEIGHT_MULTIPLIER,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF2F2F7)
                      : const Color(0xFF1C1C1E),
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'p') {
                    return {'margin': '0.5em 0'};
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EpubHighlight {
  final TextHighlight highlight;
  final Color color;
  final int startOffset;
  final int endOffset;
  final String chapterTitle;

  EpubHighlight({
    required this.highlight,
    required this.color,
    required this.startOffset,
    required this.endOffset,
    required this.chapterTitle,
  });
}

class PageLocation {
  final int chapterIndex;
  final int pageInChapter;

  PageLocation({
    required this.chapterIndex,
    required this.pageInChapter,
  });
}

class EpubPageManager {
  final double _viewportHeight;
  final Map<int, double> _chapterHeights = {};
  double _totalContentHeight = 0.0;
  final Map<int, int> _pagesPerChapter = {};
  int _totalPages = 0;

  EpubPageManager({required double viewportHeight})
      : _viewportHeight = viewportHeight;

  Future<double> _measureContentHeight(
      String content, BuildContext context) async {
    final textPainter = TextPainter(
      text: TextSpan(
        text: content,
        style: const TextStyle(
          fontSize: EpubPageCalculator.DEFAULT_FONT_SIZE,
          height: EpubPageCalculator.LINE_HEIGHT_MULTIPLIER,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 48);
    return textPainter.height;
  }

  Future<void> measureChapter(
      int index, String content, BuildContext context) async {
    // Measure actual content height
    final height = await _measureContentHeight(content, context);
    _chapterHeights[index] = height;

    // Calculate pages for this chapter
    final pagesInChapter = (height / _viewportHeight).ceil();
    _pagesPerChapter[index] = pagesInChapter;

    // Update totals
    _totalContentHeight = _chapterHeights.values.fold(0, (sum, h) => sum + h);
    _totalPages = _pagesPerChapter.values.fold(0, (sum, p) => sum + p);
  }

  int getCurrentPage(int currentChapter, double scrollOffset) {
    // Calculate absolute scroll progress
    double totalScrolled = 0;
    for (int i = 0; i < currentChapter; i++) {
      totalScrolled += _chapterHeights[i] ?? 0;
    }
    totalScrolled += scrollOffset;

    // Convert to page number
    return ((totalScrolled / _totalContentHeight) * _totalPages).ceil();
  }

  double getScrollOffsetForPage(int targetPage) {
    // Convert page to scroll position
    final targetProgress = targetPage / _totalPages;
    return targetProgress * _totalContentHeight;
  }
}

class HorizontalPageManager {
  final double pageWidth;
  final double pageHeight;
  final Map<int, List<Rect>> _pageRects = {};

  HorizontalPageManager({
    required this.pageWidth,
    required this.pageHeight,
  });

  Future<List<Rect>> _calculatePageRects(
      String content, BuildContext context) async {
    final List<Rect> rects = [];
    final textPainter = TextPainter(
      text: TextSpan(
        text: content,
        style: const TextStyle(
          fontSize: EpubPageCalculator.DEFAULT_FONT_SIZE,
          height: EpubPageCalculator.LINE_HEIGHT_MULTIPLIER,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: pageWidth - 48);

    double currentY = 0;
    double currentX = 0;

    while (currentY < textPainter.height) {
      rects.add(Rect.fromLTWH(currentX, currentY, pageWidth, pageHeight));

      if (currentY + pageHeight >= textPainter.height) {
        break;
      }

      if (currentX + pageWidth >= textPainter.width) {
        currentX = 0;
        currentY += pageHeight;
      } else {
        currentX += pageWidth;
      }
    }

    return rects;
  }

  int getTotalPages() {
    return _pageRects.values.fold(0, (sum, rects) => sum + rects.length);
  }

  PageLocation getPageLocation(int absolutePage) {
    // Convert absolute page number to chapter/page within chapter
    int accumPages = 0;
    for (final entry in _pageRects.entries) {
      if (accumPages + entry.value.length > absolutePage) {
        return PageLocation(
          chapterIndex: entry.key,
          pageInChapter: absolutePage - accumPages,
        );
      }
      accumPages += entry.value.length;
    }
    return PageLocation(
      chapterIndex: _pageRects.length - 1,
      pageInChapter: _pageRects.values.last.length,
    );
  }
}

class EPUBViewerScreen extends StatefulWidget {
  const EPUBViewerScreen({super.key});

  @override
  State<EPUBViewerScreen> createState() => _EPUBViewerScreenState();
}

class _EPUBViewerScreenState extends State<EPUBViewerScreen>
    with TickerProviderStateMixin {
  late final _geminiService = GetIt.I<GeminiService>();
  late final _characterService = GetIt.I<AiCharacterService>();
  late final _metadataRepository = GetIt.I<BookMetadataRepository>();
  late final _thumbnailService = GetIt.I<ThumbnailService>();
  final GlobalKey<FloatingChatWidgetState> _floatingChatKey = GlobalKey();
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  EpubBook? _epubBook;
  List<EpubChapter> _flatChapters = [];
  int _currentChapterIndex = 0;
  String? _selectedText;
  bool _isLoading = true;
  bool _showChapters = false;
  ImageProvider? _coverImage;
  BookMetadata? _metadata;
  bool _isDisposed = false;
  EpubLayoutMode _layoutMode = EpubLayoutMode.vertical;
  final bool _isRightToLeftReadingOrder = false;
  Timer? _sliderDwellTimer;
  num? _lastSliderValue;
  bool _isSliderInteracting = false;
  final Map<int, String> _chapterContentCache = {};
  final Map<int, List<PageContent>> _chapterPagesCache = {};
  int _totalPages = 0;
  int _currentPage = 1;
  late EpubPageCalculator _pageCalculator;
  double _fontSize = EpubPageCalculator.DEFAULT_FONT_SIZE;
  final int _totalWordsInBook = 0;
  final Map<int, int> _wordsPerChapter = {};
  final Map<int, int> _absolutePageMapping = {};
  int _nextAbsolutePage = 1;

  // Add these getters for slider values
  double get _sliderValue =>
      _currentPage.clamp(1, math.max(1, _totalPages)).toDouble();
  double get _sliderMax => math.max(1.0, _totalPages.toDouble());

  // Highlight management
  final Map<int, List<EpubHighlight>> _highlights = {};
  EpubHighlight? _highlightedMarker;
  late AnimationController _pulseController;
  Animation<double>? _pulseAnimation;
  Timer? _pulseTimer;

  // Helper: Flatten pages across chapters.
  List<PageContent> get _flattenedPages {
    List<PageContent> allPages = [];
    for (int i = 0; i < _flatChapters.length; i++) {
      if (_chapterPagesCache.containsKey(i)) {
        allPages.addAll(_chapterPagesCache[i]!);
      }
    }
    return allPages;
  }

  // Add these class variables near the top of _EPUBViewerScreenState
  double _sliderWidth = 0.0;
  final GlobalKey _sliderKey = GlobalKey();

  // Add these member variables near the top of _EPUBViewerScreenState
  late PageController _verticalPageController;
  late PageController _horizontalPageController;

  OverlayEntry? _floatingMenuEntry;
  Timer? _floatingMenuTimer;
  Offset? _lastPointerDownPosition;
  bool _showAskAiButton = false;

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController(initialPage: _currentPage - 1);
    _horizontalPageController = PageController(initialPage: _currentPage - 1);
    _initializeReader();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (_pulseTimer?.isActive == true) {
          _pulseController.forward();
        }
      }
    });

    // Load highlights after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHighlights();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize page calculator here since we need MediaQuery
    _pageCalculator = EpubPageCalculator(
      viewportWidth: MediaQuery.of(context).size.width,
      viewportHeight: MediaQuery.of(context).size.height,
    );
  }

  Future<void> _initializeReader() async {
    await Future.delayed(Duration.zero); // Wait for widget to be mounted
    if (!mounted) return;

    NavScreen.globalKey.currentState?.hideNavBar(true);
    _positionsListener.itemPositions.addListener(_onScroll);
    await _loadEpub();
  }

  @override
  void dispose() {
    if (_metadata != null && !_isDisposed) {
      _updateMetadata(_currentPage); // Final metadata save
    }
    _cleanupCache();
    _isDisposed = true;
    _positionsListener.itemPositions.removeListener(_onScroll);
    _pulseController.dispose();
    _pulseTimer?.cancel();
    _sliderDwellTimer?.cancel();
    _floatingMenuTimer?.cancel();
    _verticalPageController.dispose();
    _horizontalPageController.dispose();
    _removeFloatingMenu();
    super.dispose();
  }

  void _onScroll() {
    if (_isDisposed || _isSliderInteracting) return;

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Find the item that is most visible
    ItemPosition? bestPosition;
    double bestVisiblePortion = 0.0;

    for (final pos in positions) {
      final visiblePortion = pos.itemTrailingEdge - pos.itemLeadingEdge;
      if (visiblePortion > bestVisiblePortion) {
        bestVisiblePortion = visiblePortion;
        bestPosition = pos;
      }
    }

    if (bestPosition == null) return;

    if (_layoutMode == EpubLayoutMode.longStrip) {
      // Update current page directly from the scroll position
      final newPage = bestPosition.index + 1;
      if (newPage != _currentPage) {
        _safeSetState(() {
          _currentPage = newPage;
        });
        _updateMetadata(newPage);
      }
    } else {
      // Handle horizontal/vertical paged mode chapter tracking
      final firstIndex = positions.first.index;
      if (firstIndex != _currentChapterIndex) {
        _safeSetState(() {
          _currentChapterIndex = firstIndex;
          _loadSurroundingChapters(firstIndex);
        });
      }

      // Update progress when scrolling within the same chapter
      final page = _calculateCurrentPage();
      if (page != _currentPage && !_isSliderInteracting) {
        _safeSetState(() {
          _currentPage = page;
        });
        _updateMetadata(page);
      }
    }
  }

  int _calculateCurrentPage() {
    if (_layoutMode == EpubLayoutMode.longStrip) {
      final positions = _positionsListener.itemPositions.value;
      if (positions.isEmpty) return 1;

      // Find most visible item
      ItemPosition? bestPosition;
      double bestVisiblePortion = 0.0;

      for (final pos in positions) {
        final visiblePortion = pos.itemTrailingEdge - pos.itemLeadingEdge;
        if (visiblePortion > bestVisiblePortion) {
          bestVisiblePortion = visiblePortion;
          bestPosition = pos;
        }
      }

      return (bestPosition?.index ?? 0) + 1;
    } else {
      if (_totalPages == 0) return 1;
      return _currentPage.clamp(1, _totalPages);
    }
  }

  Future<void> _updateMetadata(int currentPage) async {
    if (_metadata == null || _isDisposed) return;

    // Ensure currentPage doesn't exceed total pages
    final validatedPage = currentPage.clamp(1, _totalPages);

    // Calculate progress as a percentage between 0.0 and 1.0
    final progress =
        _totalPages > 0 ? (validatedPage / _totalPages).clamp(0.0, 1.0) : 0.0;

    // Update metadata with current page and progress
    final updatedMetadata = _metadata!.copyWith(
      lastOpenedPage: validatedPage,
      lastReadTime: DateTime.now(),
      readingProgress: progress,
      totalPages: _totalPages, // Ensure total pages is always up to date
    );

    await _metadataRepository.saveMetadata(updatedMetadata);
    if (!_isDisposed) {
      _safeSetState(() {
        _metadata = updatedMetadata;
      });
    }
  }

  Future<void> _loadEpub() async {
    try {
      final state = context.read<FileBloc>().state;
      if (state is! FileViewing) {
        print('Not in viewing state');
        return;
      }

      _safeSetState(() {
        _isLoading = true;
        _currentPage = 1;
        _totalPages = 0;
      });

      final filePath = state.filePath;
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      _epubBook = await EpubReader.readBook(bytes);

      if (_epubBook != null) {
        _flatChapters = _flattenChapters(_epubBook!.Chapters ?? []);

        // Initialize metadata with proper error handling
        final metadata = _metadataRepository.getMetadata(filePath);
        if (metadata == null) {
          // Create new metadata if none exists
          final newMetadata = BookMetadata(
            filePath: filePath,
            title: _epubBook?.Title ?? path.basename(filePath),
            author: _epubBook?.Author,
            lastOpenedPage: 1,
            totalPages: _totalPages,
            highlights: [],
            aiConversations: [],
            isStarred: false,
            lastReadTime: DateTime.now(),
            readingProgress: 0.0,
            fileType: 'epub',
          );
          await _metadataRepository.saveMetadata(newMetadata);
          _safeSetState(() {
            _metadata = newMetadata;
            _currentPage = newMetadata.lastOpenedPage;
          });
        } else {
          _safeSetState(() {
            _metadata = metadata;
            if (metadata.lastOpenedPage > 0) {
              _currentPage = metadata.lastOpenedPage;
            }
          });
        }

        // Load chapters based on layout mode
        if (_layoutMode == EpubLayoutMode.vertical) {
          for (int i = 0; i < _flatChapters.length; i++) {
            await _preloadChapter(i);
            await _splitChapterIntoPages(i);
          }
        } else {
          await _splitChapterIntoPages(_currentChapterIndex);
          await _loadSurroundingChapters(_currentChapterIndex);
        }

        _calculateTotalPages();

        // Update metadata with correct total pages after pagination
        if (_metadata != null) {
          final updatedMetadata = _metadata!.copyWith(
            totalPages: _totalPages,
            readingProgress: _totalPages > 0
                ? (_currentPage / _totalPages).clamp(0.0, 1.0)
                : 0.0,
          );
          await _metadataRepository.saveMetadata(updatedMetadata);
          _safeSetState(() {
            _metadata = updatedMetadata;
            _isLoading = false;
          });
        } else {
          _safeSetState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading EPUB: $e');
      if (!_isDisposed && mounted) {
        Utils.showErrorSnackBar(context, 'Error loading EPUB: $e');
      }
    }
  }

  void _calculateTotalPages() {
    if (_layoutMode == EpubLayoutMode.vertical) {
      _safeSetState(() {
        _totalPages = _flattenedPages.length;
      });
    } else {
      int total = 0;
      for (var i = 0; i < _flatChapters.length; i++) {
        total += _chapterPagesCache[i]?.length ?? 0;
      }
      _safeSetState(() {
        _totalPages = total > 0 ? total : 1;
      });
    }
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 || index >= _flatChapters.length) return;
    if (_chapterContentCache.containsKey(index)) return;

    try {
      final chapter = _flatChapters[index];
      String content = chapter.HtmlContent ?? '';
      content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (content.isEmpty) {
        content = '<p>Chapter content unavailable</p>';
      }

      _chapterContentCache[index] = content;
      final wordCount = content.split(RegExp(r'\s+')).length;
      _wordsPerChapter[index] = wordCount;
      _calculateTotalPages();
    } catch (e) {
      print('Error preloading chapter $index: $e');
      _chapterContentCache[index] = '<p>Error loading chapter content</p>';
      _wordsPerChapter[index] = 0;
    }
  }

  void _cleanupCache() {
    // Keep more chapters in memory to prevent content loss
    final chaptersToKeep = <int>{
      _currentChapterIndex - 2,
      _currentChapterIndex - 1,
      _currentChapterIndex,
      _currentChapterIndex + 1,
      _currentChapterIndex + 2,
    };

    _chapterContentCache.removeWhere((key, value) =>
        !chaptersToKeep.contains(key) &&
        key >= 0 &&
        key < _flatChapters.length);
    _chapterPagesCache.removeWhere((key, value) =>
        !chaptersToKeep.contains(key) &&
        key >= 0 &&
        key < _flatChapters.length);
  }

  Future<bool> _handleBackPress() async {
    try {
      if (_metadata != null) {
        await _updateMetadata(_currentPage);

        if (mounted) {
          context.read<ReaderBloc>().add(CloseReader());
          context.read<FileBloc>().add(CloseViewer());
        }
      }
      return true;
    } catch (e) {
      print('Error handling back press: $e');
      return false;
    }
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters,
      [int level = 0]) {
    List<EpubChapter> result = [];
    for (var chapter in chapters) {
      result.add(chapter);
      if (chapter.SubChapters?.isNotEmpty == true) {
        result.addAll(_flattenChapters(chapter.SubChapters!, level + 1));
      }
    }
    return result;
  }

  void _handleChatMessage(String? message, {String? selectedText}) async {
    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

    final bookTitle = _epubBook?.Title ?? path.basename(state.file.path);
    final currentPage = _currentChapterIndex + 1;
    final totalPages = _flatChapters.length;

    try {
      final response = await _geminiService.askAboutText(
        selectedText ?? '',
        customPrompt: message ??
            'Can you explain what the text is about? After that share your thoughts in a single open ended question in the same paragraph, make the question short and concise.',
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
      );

      if (!mounted) return;

      if (_floatingChatKey.currentState != null) {
        _floatingChatKey.currentState!.addAiResponse(response);
      }
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorSnackBar(context, 'Failed to get AI response');
    }
  }

  void _handleLayoutChange(EpubLayoutMode mode) async {
    _safeSetState(() {
      _isLoading = true;
      _layoutMode = mode;
    });

    try {
      // Re-paginate all chapters when changing layout mode
      _chapterPagesCache.clear();
      for (int i = 0; i < _flatChapters.length; i++) {
        await _splitChapterIntoPages(i);
      }

      _calculateTotalPages();

      // Reset page controllers
      _verticalPageController = PageController(initialPage: _currentPage - 1);
      _horizontalPageController = PageController(initialPage: _currentPage - 1);

      if (mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
      }

      // Jump to current page in new layout
      await _jumpToPage(_currentPage);
    } catch (e) {
      print('Error changing layout: $e');
      if (mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _splitChapterIntoPages(int chapterIndex) async {
    if (_chapterPagesCache.containsKey(chapterIndex)) return;

    final chapter = _flatChapters[chapterIndex];
    String content = _chapterContentCache[chapterIndex] ?? '';

    try {
      // Calculate pages using the page calculator
      final pages = await _pageCalculator.calculatePages(
        content,
        chapterIndex,
        chapter.Title ?? 'Chapter ${chapterIndex + 1}',
      );

      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[chapterIndex] = pages;
        });
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error splitting chapter $chapterIndex into pages: $e');
      // Add a single page with error message
      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[chapterIndex] = [
            PageContent(
              content: '<p>Error loading chapter content</p>',
              chapterIndex: chapterIndex,
              pageNumberInChapter: 1,
              chapterTitle: chapter.Title ?? 'Chapter ${chapterIndex + 1}',
            )
          ];
        });
      }
    }
  }

  Future<void> _loadSurroundingChapters(int currentChapterIndex) async {
    final chaptersToLoad = <int>{
      currentChapterIndex - 1,
      currentChapterIndex,
      currentChapterIndex + 1,
    };

    for (final index in chaptersToLoad) {
      if (index >= 0 && index < _flatChapters.length) {
        // Ensure chapter content is loaded
        await _preloadChapter(index);

        // Split into pages if not already done
        if (!_chapterPagesCache.containsKey(index)) {
          await _splitChapterIntoPages(index);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (state is ReaderLoaded) {
          final showUI = state.showUI;

          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) async {
              if (didPop) {
                await _handleBackPress();
              }
            },
            child: GestureDetector(
              onTap: _handleTap,
              behavior: HitTestBehavior.deferToChild,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    // Content layer
                    if (_layoutMode == EpubLayoutMode.horizontal)
                      _buildHorizontalLayout()
                    else if (_layoutMode == EpubLayoutMode.vertical)
                      _buildVerticalPagedLayout()
                    else if (_layoutMode == EpubLayoutMode.longStrip)
                      ScrollablePositionedList.builder(
                        itemCount: _flattenedPages.length,
                        itemBuilder: (context, index) {
                          final page = _flattenedPages[index];
                          return _buildPage(page);
                        },
                        itemScrollController: _scrollController,
                        itemPositionsListener: _positionsListener,
                      )
                    else
                      _buildHorizontalLayout(),

                    // UI elements
                    if (showUI) ...[
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppBar(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF251B2F).withOpacity(0.95)
                                  : const Color(0xFFFAF9F7).withOpacity(0.95),
                          elevation: 0,
                          toolbarHeight:
                              ResponsiveConstants.getBottomBarHeight(context),
                          leading: IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                              size: ResponsiveConstants.getIconSize(context),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  NavScreen.globalKey.currentState
                                      ?.hideNavBar(false);
                                }
                              });
                            },
                          ),
                          title: Text(
                            _epubBook?.Title ?? path.basename(state.file.path),
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConstants.getBodyFontSize(context),
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          actions: [
                            IconButton(
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                              ),
                              onPressed: () {
                                // TODO: Implement search functionality for EPUB
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Search coming soon for EPUB files'),
                                  ),
                                );
                              },
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.menu,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                              ),
                              onPressed: () {
                                _safeSetState(() {
                                  _showChapters = !_showChapters;
                                });
                              },
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                            ),
                            PopupMenuButton<String>(
                              elevation: 8,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF352A3B)
                                  : const Color(0xFFF8F1F1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              icon: Icon(
                                Icons.more_vert,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                              ),
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                              position: PopupMenuPosition.under,
                              onSelected: (val) async {
                                switch (val) {
                                  case 'layout_mode':
                                    final RenderBox button =
                                        context.findRenderObject() as RenderBox;
                                    final RenderBox overlay =
                                        Navigator.of(context)
                                            .overlay!
                                            .context
                                            .findRenderObject() as RenderBox;
                                    final buttonPos =
                                        button.localToGlobal(Offset.zero);
                                    final overlayPos =
                                        overlay.localToGlobal(Offset.zero);

                                    final RelativeRect position =
                                        RelativeRect.fromLTRB(
                                      buttonPos.dx,
                                      buttonPos.dy + button.size.height,
                                      overlayPos.dx +
                                          overlay.size.width -
                                          buttonPos.dx -
                                          button.size.width,
                                      overlayPos.dy +
                                          overlay.size.height -
                                          buttonPos.dy,
                                    );

                                    showMenu<EpubLayoutMode>(
                                      context: context,
                                      position: position,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF352A3B)
                                          : const Color(0xFFF8F1F1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      items: [
                                        PopupMenuItem(
                                          value: EpubLayoutMode.longStrip,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.view_day,
                                                color: _layoutMode ==
                                                        EpubLayoutMode.longStrip
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : null,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text('Long Strip',
                                                  style: TextStyle(
                                                    color: _layoutMode ==
                                                            EpubLayoutMode
                                                                .longStrip
                                                        ? Theme.of(context)
                                                            .primaryColor
                                                        : null,
                                                  )),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: EpubLayoutMode.vertical,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.vertical_distribute,
                                                color: _layoutMode ==
                                                        EpubLayoutMode.vertical
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : null,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text('Vertical Scroll',
                                                  style: TextStyle(
                                                    color: _layoutMode ==
                                                            EpubLayoutMode
                                                                .vertical
                                                        ? Theme.of(context)
                                                            .primaryColor
                                                        : null,
                                                  )),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: EpubLayoutMode.horizontal,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.horizontal_distribute,
                                                color: _layoutMode ==
                                                        EpubLayoutMode
                                                            .horizontal
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : null,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text('Horizontal Scroll',
                                                  style: TextStyle(
                                                    color: _layoutMode ==
                                                            EpubLayoutMode
                                                                .horizontal
                                                        ? Theme.of(context)
                                                            .primaryColor
                                                        : null,
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ).then((EpubLayoutMode? mode) {
                                      if (mode != null && mounted) {
                                        _handleLayoutChange(mode);
                                      }
                                    });
                                    break;
                                  case 'reading_mode':
                                    final readingMode =
                                        await showMenu<ReadingMode>(
                                      context: context,
                                      position: RelativeRect.fromLTRB(
                                        MediaQuery.of(context).size.width - 200,
                                        kToolbarHeight + 20,
                                        MediaQuery.of(context).size.width - 10,
                                        kToolbarHeight + 100,
                                      ),
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF352A3B)
                                          : const Color(0xFFF8F1F1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      items: [
                                        PopupMenuItem(
                                          value: ReadingMode.light,
                                          child: Text('Light',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFF2F2F7)
                                                      : const Color(
                                                          0xFF1C1C1E))),
                                        ),
                                        PopupMenuItem(
                                          value: ReadingMode.dark,
                                          child: Text('Dark',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFF2F2F7)
                                                      : const Color(
                                                          0xFF1C1C1E))),
                                        ),
                                        PopupMenuItem(
                                          value: ReadingMode.sepia,
                                          child: Text('Sepia',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFF2F2F7)
                                                      : const Color(
                                                          0xFF1C1C1E))),
                                        ),
                                      ],
                                    );
                                    if (readingMode != null && mounted) {
                                      context
                                          .read<ReaderBloc>()
                                          .add(setReadingMode(readingMode));
                                    }
                                    break;
                                  case 'move_trash':
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete File'),
                                        content: const Text(
                                            'Are you sure you want to delete this file? This action cannot be undone.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (shouldDelete == true && mounted) {
                                      try {
                                        final file = File(state.file.path);
                                        if (await file.exists()) {
                                          await file.delete();
                                          if (mounted) {
                                            context.read<FileBloc>().add(
                                                RemoveFile(state.file.path));
                                            context
                                                .read<ReaderBloc>()
                                                .add(CloseReader());
                                            Navigator.of(context).pop();
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Error deleting file: $e')),
                                          );
                                        }
                                      }
                                    }
                                    break;
                                  case 'share':
                                    try {
                                      final file = File(state.file.path);
                                      if (await file.exists()) {
                                        await Share.share(
                                          state.file.path,
                                          subject:
                                              path.basename(state.file.path),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error sharing file: $e')),
                                        );
                                      }
                                    }
                                    break;
                                  case 'toggle_star':
                                    context
                                        .read<FileBloc>()
                                        .add(ToggleStarred(state.file.path));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Updated starred status'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    break;
                                  case 'mark_as_read':
                                    context
                                        .read<FileBloc>()
                                        .add(ViewFile(state.file.path));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Marked as read'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                    break;
                                  case 'font_size':
                                    _showFontSizeDialog();
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'layout_mode',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.view_agenda_outlined,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Page Layout',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_right,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'reading_mode',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.palette_outlined,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Reading Mode',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_right,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'move_trash',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Move to trash',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.share_outlined,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Share file',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle_star',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_outline,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Toggle star',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'mark_as_read',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Mark as read',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'font_size',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.format_size,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Font Size',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_right,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Side navigation (Chapters)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        top: 0,
                        bottom: 0,
                        left: _showChapters
                            ? 0
                            : -ResponsiveConstants.getSideNavWidth(context),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            if (details.delta.dx < 0) {
                              // Only handle left swipes
                              _safeSetState(() {
                                _showChapters = false;
                              });
                            }
                          },
                          child: Container(
                            width: ResponsiveConstants.getSideNavWidth(context),
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF251B2F).withOpacity(0.98)
                                    : const Color(0xFFFAF9F7).withOpacity(0.98),
                            child: SafeArea(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          ResponsiveConstants.isTablet(context)
                                              ? 24
                                              : 16,
                                      vertical:
                                          ResponsiveConstants.isTablet(context)
                                              ? 16
                                              : 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Chapters',
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E),
                                            fontSize: ResponsiveConstants
                                                .getTitleFontSize(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(
                                            minWidth:
                                                ResponsiveConstants.getIconSize(
                                                    context),
                                            minHeight:
                                                ResponsiveConstants.getIconSize(
                                                    context),
                                          ),
                                          icon: Icon(
                                            Icons.close,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF8E8E93)
                                                    : const Color(0xFF6E6E73),
                                            size:
                                                ResponsiveConstants.getIconSize(
                                                    context),
                                          ),
                                          onPressed: () {
                                            _safeSetState(() {
                                              _showChapters = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _flatChapters.length,
                                      itemBuilder: (context, index) {
                                        final chapter = _flatChapters[index];
                                        return ListTile(
                                          title: Text(
                                            chapter.Title ??
                                                'Chapter ${index + 1}',
                                            style: TextStyle(
                                              color: _currentChapterIndex ==
                                                      index
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? const Color(0xFFF2F2F7)
                                                      : const Color(0xFF1C1C1E),
                                              fontSize: ResponsiveConstants
                                                  .getBodyFontSize(context),
                                            ),
                                          ),
                                          onTap: () {
                                            _scrollController.scrollTo(
                                              index: index,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                            );
                                            _safeSetState(() {
                                              _showChapters = false;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF251B2F).withOpacity(0.95)
                              : const Color(0xFFFAF9F7).withOpacity(0.95),
                          padding: EdgeInsets.fromLTRB(
                            ResponsiveConstants.getContentPadding(context)
                                    .horizontal /
                                2,
                            0,
                            ResponsiveConstants.getContentPadding(context)
                                    .horizontal /
                                2,
                            ResponsiveConstants.getContentPadding(context)
                                    .bottom +
                                10.0,
                          ),
                          height:
                              ResponsiveConstants.getBottomBarHeight(context),
                          child: Row(
                            children: [
                              Text(
                                '${_calculateCurrentPage()}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  fontSize: ResponsiveConstants.getBodyFontSize(
                                      context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    _sliderWidth = constraints.maxWidth;
                                    return GestureDetector(
                                      key: _sliderKey,
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) => _handleSliderTap(
                                          details, constraints.maxWidth),
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight:
                                              ResponsiveConstants.isTablet(
                                                      context)
                                                  ? 4
                                                  : 2,
                                          activeTrackColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFAA96B6)
                                                  : const Color(0xFF9E7B80),
                                          inactiveTrackColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF352A3B)
                                                  : const Color(0xFFF8F1F1),
                                          thumbColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFAA96B6)
                                                  : const Color(0xFF9E7B80),
                                          overlayColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFAA96B6)
                                                      .withOpacity(0.12)
                                                  : const Color(0xFF9E7B80)
                                                      .withOpacity(0.12),
                                          thumbShape: RoundSliderThumbShape(
                                            enabledThumbRadius:
                                                ResponsiveConstants.isTablet(
                                                        context)
                                                    ? 8
                                                    : 6,
                                          ),
                                          overlayShape: RoundSliderOverlayShape(
                                            overlayRadius:
                                                ResponsiveConstants.isTablet(
                                                        context)
                                                    ? 16
                                                    : 12,
                                          ),
                                        ),
                                        child: Slider(
                                          value: _sliderValue,
                                          min: 1,
                                          max: _sliderMax,
                                          onChangeStart:
                                              _handleSliderChangeStart,
                                          onChanged: _handleSliderChanged,
                                          onChangeEnd: _handleSliderChangeEnd,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$_totalPages',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  fontSize: ResponsiveConstants.getBodyFontSize(
                                      context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildHorizontalLayout() {
    return Container(
      padding: EdgeInsets.only(
        top: ResponsiveConstants.getBottomBarHeight(context),
        bottom: ResponsiveConstants.getBottomBarHeight(context),
      ),
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        controller: _horizontalPageController,
        onPageChanged: (index) {
          if (!_isDisposed && mounted) {
            _safeSetState(() {
              _currentPage = index + 1;
            });
            _updateMetadata(_currentPage);
          }
        },
        itemBuilder: (context, pageIndex) {
          // Find which chapter this page belongs to
          int currentCount = 0;
          int targetChapterIndex = 0;
          int pageInChapter = 0;

          for (var i = 0; i < _flatChapters.length; i++) {
            final chapterPages = _chapterPagesCache[i]?.length ?? 0;
            if (currentCount + chapterPages > pageIndex) {
              targetChapterIndex = i;
              pageInChapter = pageIndex - currentCount;
              break;
            }
            currentCount += chapterPages;
          }

          // Load the chapter if needed
          if (!_chapterPagesCache.containsKey(targetChapterIndex)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadChapter(targetChapterIndex);
            });
            return const Center(child: CircularProgressIndicator());
          }

          final pages = _chapterPagesCache[targetChapterIndex];
          if (pages == null || pageInChapter >= pages.length) {
            return const Center(child: Text('Page not available'));
          }

          return _buildPage(pages[pageInChapter]);
        },
        itemCount: _totalPages,
      ),
    );
  }

  Widget _buildVerticalPagedLayout() {
    return Container(
      padding: EdgeInsets.only(
        top: ResponsiveConstants.getBottomBarHeight(context),
        bottom: ResponsiveConstants.getBottomBarHeight(context),
      ),
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _verticalPageController,
        onPageChanged: (index) {
          if (!_isDisposed && mounted) {
            _safeSetState(() {
              _currentPage = index + 1;
            });
            _updateMetadata(_currentPage);
          }
        },
        itemBuilder: (context, pageIndex) {
          // Find which chapter this page belongs to
          int currentCount = 0;
          int targetChapterIndex = 0;
          int pageInChapter = 0;

          for (var i = 0; i < _flatChapters.length; i++) {
            final chapterPages = _chapterPagesCache[i]?.length ?? 0;
            if (currentCount + chapterPages > pageIndex) {
              targetChapterIndex = i;
              pageInChapter = pageIndex - currentCount;
              break;
            }
            currentCount += chapterPages;
          }

          // Load the chapter if needed
          if (!_chapterPagesCache.containsKey(targetChapterIndex)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadChapter(targetChapterIndex);
            });
            return const Center(child: CircularProgressIndicator());
          }

          final pages = _chapterPagesCache[targetChapterIndex];
          if (pages == null || pageInChapter >= pages.length) {
            return const Center(child: Text('Page not available'));
          }

          return _buildPage(pages[pageInChapter]);
        },
        itemCount: _totalPages,
      ),
    );
  }

  void _handleTap() {
    // Close any open side widgets first
    if (_showChapters) {
      _safeSetState(() {
        _showChapters = false;
      });
      return;
    }

    // Toggle UI visibility after handling side widgets
    context.read<ReaderBloc>().add(ToggleUIVisibility());
  }

  Widget _buildPage(PageContent page) {
    return SelectionArea(
      onSelectionChanged: (selection) {
        final selectedText = selection?.plainText ?? '';
        _handleTextSelectionChange(
            selectedText.isNotEmpty ? selectedText : null);
      },
      child: Listener(
        onPointerDown: (event) {
          _lastPointerDownPosition = event.position;
        },
        onPointerUp: (event) {
          final anchor = _lastPointerDownPosition ?? event.position;
          if (mounted && _selectedText?.isNotEmpty == true) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _selectedText?.isNotEmpty == true) {
                _showFloatingMenuAt(anchor);
              }
            });
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal:
                ResponsiveConstants.getContentPadding(context).horizontal,
          ),
          child: HtmlWidget(
            page.content,
            textStyle: TextStyle(
              fontSize: _fontSize,
              height: 1.5,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadChapter(int index) async {
    if (_chapterPagesCache.containsKey(index)) return;

    final chapter = _flatChapters[index];
    if (chapter.HtmlContent == null) return;

    try {
      final pages = await _pageCalculator.calculatePages(
        chapter.HtmlContent!,
        index,
        chapter.Title ?? 'Chapter ${index + 1}',
      );

      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[index] = pages;
        });
        // Update total pages whenever a new chapter is loaded
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error calculating pages for chapter $index: $e');
    }
  }

  void _startPulsingHighlight(EpubHighlight highlight) {
    _safeSetState(() {
      _highlightedMarker = highlight;
    });

    _pulseTimer?.cancel();
    _pulseController.forward();

    // Pulse for 3 cycles
    _pulseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _safeSetState(() {
          _highlightedMarker = null;
        });
        _pulseController.stop();
        _pulseController.reset();
        _pulseTimer = null;
      }
    });
  }

  void _addHighlight(String text, int chapterIndex, int startOffset,
      int endOffset, Color color) {
    final highlight = TextHighlight(
      text: text,
      pageNumber: chapterIndex + 1,
      createdAt: DateTime.now(),
    );

    final epubHighlight = EpubHighlight(
      highlight: highlight,
      color: color,
      startOffset: startOffset,
      endOffset: endOffset,
      chapterTitle:
          _flatChapters[chapterIndex].Title ?? 'Chapter ${chapterIndex + 1}',
    );

    _safeSetState(() {
      if (!_highlights.containsKey(chapterIndex)) {
        _highlights[chapterIndex] = [];
      }
      _highlights[chapterIndex]!.add(epubHighlight);
    });

    // Update metadata with a new list
    if (_metadata != null) {
      final updatedMetadata = _metadata!.copyWith(
        highlights: List<TextHighlight>.from(_metadata!.highlights)
          ..add(highlight),
      );
      _metadataRepository.saveMetadata(updatedMetadata);
      _safeSetState(() {
        _metadata = updatedMetadata;
      });
    }

    // Start pulsing animation
    _startPulsingHighlight(epubHighlight);
  }

  void _removeHighlight(EpubHighlight highlight) {
    for (final entry in _highlights.entries) {
      final index = entry.value.indexOf(highlight);
      if (index != -1) {
        _safeSetState(() {
          entry.value.removeAt(index);
          if (entry.value.isEmpty) {
            _highlights.remove(entry.key);
          }
        });

        // Update metadata with a new list
        if (_metadata != null) {
          final updatedHighlights =
              List<TextHighlight>.from(_metadata!.highlights)
                ..removeWhere((h) =>
                    h.text == highlight.highlight.text &&
                    h.pageNumber == highlight.highlight.pageNumber);

          final updatedMetadata = _metadata!.copyWith(
            highlights: updatedHighlights,
          );
          _metadataRepository.saveMetadata(updatedMetadata);
          _safeSetState(() {
            _metadata = updatedMetadata;
          });
        }
        break;
      }
    }
  }

  Future<void> _loadHighlights() async {
    if (_metadata == null || _isDisposed) return;

    final highlights = _metadata!.highlights;
    for (final highlight in highlights) {
      final chapterIndex = highlight.pageNumber - 1;
      if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) continue;

      await _preloadChapter(chapterIndex);
      final content = _chapterContentCache[chapterIndex];
      if (content == null) continue;

      // Find the text in the chapter content
      final index = content.indexOf(highlight.text);
      if (index != -1) {
        final epubHighlight = EpubHighlight(
          highlight: highlight,
          color: Colors.yellow,
          startOffset: index,
          endOffset: index + highlight.text.length,
          chapterTitle: _flatChapters[chapterIndex].Title ??
              'Chapter ${chapterIndex + 1}',
        );

        _safeSetState(() {
          if (!_highlights.containsKey(chapterIndex)) {
            _highlights[chapterIndex] = [];
          }
          _highlights[chapterIndex]!.add(epubHighlight);
        });
      }
    }
  }

  void _handleTextSelectionChange(String? selectedText) {
    if (selectedText?.isNotEmpty == true) {
      _safeSetState(() {
        _selectedText = selectedText;
        _showAskAiButton = true;
      });
    } else {
      _safeSetState(() {
        _selectedText = null;
        _showAskAiButton = false;
      });
      _removeFloatingMenu();
    }
  }

  void _showFloatingMenuAt(Offset anchor) {
    final screenSize = MediaQuery.of(context).size;
    final bool isInUpperHalf = anchor.dy < (screenSize.height / 2);
    _removeFloatingMenu();

    // Calculate positions
    double menuTop;
    final double quickActionsBottom =
        isInUpperHalf ? anchor.dy + 48 : anchor.dy - 48;
    final double quickActionsTop =
        isInUpperHalf ? anchor.dy - 8 : anchor.dy - 88;

    // Position main menu at bottom or top based on selection position
    if (isInUpperHalf) {
      menuTop = screenSize.height * 0.57;
    } else {
      menuTop = -20;
    }

    // Create overlay entry with both quick actions and main menu
    _floatingMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Main menu
          Positioned(
            left: 16,
            right: 16,
            top: menuTop,
            child: Material(
              color: Colors.transparent,
              child: FloatingSelectionMenu(
                selectedText: _selectedText ?? '',
                displayAtTop: !isInUpperHalf,
                onMenuSelected: (menuType, text) {
                  _removeFloatingMenu();
                  switch (menuType) {
                    case SelectionMenuType.askAi:
                    case SelectionMenuType.translate:
                    case SelectionMenuType.dictionary:
                    case SelectionMenuType.wikipedia:
                    case SelectionMenuType.generateImage:
                      showDialog(
                        context: context,
                        barrierColor: Colors.transparent,
                        barrierDismissible: false,
                        builder: (context) => Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (_) {},
                              ),
                            ),
                            FullSelectionMenu(
                              selectedText: text,
                              menuType: menuType,
                              onDismiss: () => Navigator.pop(context),
                              floatingChatKey: _floatingChatKey,
                            ),
                          ],
                        ),
                      );
                      break;
                    default:
                      break;
                  }
                },
                onDismiss: _removeFloatingMenu,
                onExpand: () {
                  _removeFloatingMenu();
                  showDialog(
                    context: context,
                    barrierColor: Colors.transparent,
                    barrierDismissible: false,
                    builder: (context) => Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (_) {},
                          ),
                        ),
                        FullSelectionMenu(
                          selectedText: _selectedText ?? '',
                          menuType: SelectionMenuType.askAi,
                          onDismiss: () => Navigator.pop(context),
                          floatingChatKey: _floatingChatKey,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Quick action buttons near text selection
          Positioned(
            left: max(16, anchor.dx - 120),
            top: isInUpperHalf ? quickActionsTop : quickActionsBottom,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF352A3B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Highlight button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        onTap: () {
                          _removeFloatingMenu();
                          if (_selectedText != null &&
                              _selectedText!.isNotEmpty) {
                            // Add highlight to the selected text
                            final state = context.read<ReaderBloc>().state;
                            if (state is ReaderLoaded) {
                              context.read<ReaderBloc>().add(AddHighlight(
                                    text: _selectedText!,
                                    note: null,
                                    pageNumber: state.currentPage,
                                  ));

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Highlight added'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.highlight,
                                size: 20,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Highlight',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFAA96B6)
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 24,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF4A4A4A)
                          : const Color(0xFFE0E0E0),
                    ),

                    // Audio button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(20),
                        ),
                        onTap: () {
                          _removeFloatingMenu();
                          // Show the audio dialog
                          showDialog(
                            context: context,
                            barrierColor: Colors.transparent,
                            barrierDismissible: false,
                            builder: (context) => Stack(
                              children: [
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTapDown: (_) {},
                                  ),
                                ),
                                FullSelectionMenu(
                                  selectedText: _selectedText ?? '',
                                  menuType: SelectionMenuType.audio,
                                  onDismiss: () => Navigator.pop(context),
                                  floatingChatKey: _floatingChatKey,
                                ),
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_outlined,
                                size: 20,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Audio',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFAA96B6)
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_floatingMenuEntry!);
  }

  void _removeFloatingMenu() {
    _floatingMenuEntry?.remove();
    _floatingMenuEntry = null;
    _floatingMenuTimer?.cancel();
    _floatingMenuTimer = null;
  }

  void _handleAskAi(String selectedText) {
    _floatingChatKey.currentState?.showChat();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      _floatingChatKey.currentState!
          .addUserMessage('Imported Text: """$selectedText"""');
      _handleChatMessage(null, selectedText: selectedText);
    });
  }

  void _calculatePages() {
    if (_isDisposed) return;

    // Reset mappings if needed
    if (_absolutePageMapping.isEmpty) {
      _nextAbsolutePage = 1;
    }

    // Calculate fixed pages for each chapter
    for (var i = 0; i < _flatChapters.length; i++) {
      if (!_absolutePageMapping.containsKey(i) &&
          _chapterPagesCache.containsKey(i)) {
        final pages = _chapterPagesCache[i]!;
        for (var j = 0; j < pages.length; j++) {
          _absolutePageMapping[_nextAbsolutePage] = i;
          _nextAbsolutePage++;
        }
      }
    }

    _safeSetState(() {
      _totalPages = _nextAbsolutePage - 1;
    });
  }

  int _getCurrentPage() {
    // Find the absolute page number based on current chapter and scroll position
    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return 1;

    final firstPosition = positions.first;
    final chapterIndex = firstPosition.index;

    // Find the first absolute page number for this chapter
    int absolutePage = 1;
    for (var entry in _absolutePageMapping.entries) {
      if (entry.value == chapterIndex) {
        absolutePage = entry.key;
        break;
      }
    }

    // Add offset based on scroll position within chapter
    if (_chapterPagesCache.containsKey(chapterIndex)) {
      final chapterPages = _chapterPagesCache[chapterIndex]!;
      final progress = 1.0 - firstPosition.itemLeadingEdge;
      final pageOffset = (progress * chapterPages.length).floor();
      absolutePage += pageOffset;
    }

    return absolutePage.clamp(1, _totalPages);
  }

  Future<void> _jumpToPage(num targetPage) async {
    final safePage = targetPage.clamp(1, math.max(1, _totalPages));

    if (_layoutMode == EpubLayoutMode.vertical) {
      await _verticalPageController.animateToPage(
        (safePage - 1).toInt(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_layoutMode == EpubLayoutMode.horizontal) {
      await _horizontalPageController.animateToPage(
        (safePage - 1).toInt(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_layoutMode == EpubLayoutMode.longStrip) {
      if (_scrollController.isAttached && mounted) {
        await _scrollController.scrollTo(
          index: (safePage - 1).toInt(),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    _safeSetState(() {
      _currentPage = safePage.toInt();
    });
  }

  // Add this method to check if a tap position is on a UI element
  bool _isUIElement(Offset position) {
    // Get screen dimensions
    final size = MediaQuery.of(context).size;

    // Define UI element regions
    final topBarRegion = Rect.fromLTWH(0, 0, size.width, kToolbarHeight);
    final bottomBarRegion = Rect.fromLTWH(
        0,
        size.height - ResponsiveConstants.getBottomBarHeight(context),
        size.width,
        ResponsiveConstants.getBottomBarHeight(context));

    // Check if tap is in any UI region
    return topBarRegion.contains(position) ||
        bottomBarRegion.contains(position);
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _fontSize,
                min: 12.0,
                max: 32.0,
                divisions: 20,
                label: _fontSize.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _fontSize = value;
                  });
                },
                onChangeEnd: (value) async {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                    });
                  }

                  try {
                    double oldProgress =
                        _totalPages > 0 ? _currentPage / _totalPages : 0.0;

                    final newCalculator = EpubPageCalculator(
                      viewportWidth: MediaQuery.of(context).size.width,
                      viewportHeight: MediaQuery.of(context).size.height,
                      fontSize: value,
                    );

                    _chapterPagesCache.clear();
                    _absolutePageMapping.clear();
                    _nextAbsolutePage = 1;

                    setState(() {
                      _fontSize = value;
                      _pageCalculator = newCalculator;
                    });

                    for (int i = 0; i < _flatChapters.length; i++) {
                      await _splitChapterIntoPages(i);
                    }
                    _calculateTotalPages();

                    int newCurrentPage = _totalPages > 0
                        ? (oldProgress * _totalPages).round()
                        : 1;
                    newCurrentPage = newCurrentPage.clamp(1, _totalPages);

                    _verticalPageController =
                        PageController(initialPage: newCurrentPage - 1);
                    _horizontalPageController =
                        PageController(initialPage: newCurrentPage - 1);

                    if (mounted) {
                      setState(() {
                        _currentPage = newCurrentPage;
                        _isLoading = false;
                      });
                    }

                    await _jumpToPage(newCurrentPage);
                    await _updateMetadata(
                        newCurrentPage); // Update metadata after pagination changes
                  } catch (e) {
                    print('Error updating font size: $e');
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sample Text\nMultiple lines to preview text size and spacing.',
                  style: TextStyle(fontSize: _fontSize),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleSliderTap(TapDownDetails details, double width) {
    if (_totalPages <= 1) return;

    final localOffset = details.localPosition;
    double tappedRatio = (localOffset.dx / width).clamp(0.0, 1.0);
    int newPage = ((tappedRatio * (_totalPages - 1)) + 1).round();
    newPage = newPage.clamp(1, _totalPages);

    _safeSetState(() {
      _currentPage = newPage;
      _isSliderInteracting = true;
    });

    _jumpToPage(newPage);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _safeSetState(() {
          _isSliderInteracting = false;
        });
      }
    });
  }

  void _handleSliderChangeStart(double value) {
    _sliderDwellTimer?.cancel();
    _lastSliderValue = value.toInt();
    _safeSetState(() {
      _isSliderInteracting = true;
    });
  }

  void _handleSliderChanged(double value) {
    final intValue = value.toInt().clamp(1, math.max(1, _totalPages));
    if (_lastSliderValue != intValue) {
      _sliderDwellTimer?.cancel();
      _lastSliderValue = intValue;

      _safeSetState(() {
        _currentPage = intValue.toInt();
      });
    }
  }

  void _handleSliderChangeEnd(double value) {
    _sliderDwellTimer?.cancel();
    final intValue = value.toInt().clamp(1, math.max(1, _totalPages));
    _jumpToPage(intValue);

    Future.delayed(const Duration(milliseconds: 200), () {
      _safeSetState(() {
        _isSliderInteracting = false;
        _lastSliderValue = null;
      });
    });
  }
}
