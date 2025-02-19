import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:read_leaf/screens/nav_screen.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/widgets/CompanionChat/floating_chat_widget.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:read_leaf/services/thumbnail_service.dart';
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/providers/theme_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:read_leaf/widgets/floating_selection_menu.dart';
import 'package:read_leaf/widgets/full_selection_menu.dart';
import 'package:flutter/gestures.dart';

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
  // Constants for pagination
  static const double DEFAULT_FONT_SIZE = 23.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 32.0;
  static const int WORDS_PER_PAGE = 550;
  static const double PAGE_HEIGHT_FRACTION = 0.835;

  // Cache structures
  final Map<int, List<PageContent>> _pageCache = {};
  final Map<String, TextStyle> _styleCache = {};

  // Content metrics
  late final double _viewportWidth;
  late final double _viewportHeight;
  late final double _fontSize;
  late final double _effectiveViewportHeight;

  // Initialize calculator with viewport dimensions
  EpubPageCalculator({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = DEFAULT_FONT_SIZE,
  }) {
    final double fixedHeight = viewportHeight * PAGE_HEIGHT_FRACTION;
    _viewportWidth = viewportWidth - (PAGE_PADDING * 2);
    _viewportHeight = fixedHeight;
    _fontSize = fontSize;
    _effectiveViewportHeight = _viewportHeight - (PAGE_PADDING * 2);
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
      if (p.startsWith('<h1>'))
        tag = 'h1';
      else if (p.startsWith('<h2>')) tag = 'h2';

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

  // Calculate page breaks based on measured block heights
  List<PageContent> _calculatePageBreaks(
    ParsedContent content,
    int chapterIndex,
    String chapterTitle,
  ) {
    final pages = <PageContent>[];
    List<String> currentPageBlocks = [];
    double currentPageHeight = 0.0;

    for (var block in content.blocks) {
      final blockHeight = _measureBlockHeight(block);
      // If adding the block does not exceed the effective page height, add it
      if (currentPageHeight + blockHeight <= _effectiveViewportHeight) {
        currentPageBlocks.add(block.rawHtml);
        currentPageHeight += blockHeight;
      } else {
        // If there is content accumulated on this page, push it as a new page
        if (currentPageBlocks.isNotEmpty) {
          pages.add(PageContent(
            content: currentPageBlocks.join('\n'),
            chapterIndex: chapterIndex,
            pageNumberInChapter: pages.length + 1,
            chapterTitle: chapterTitle,
          ));
          // Start a new page with the current block
          currentPageBlocks = [block.rawHtml];
          currentPageHeight = blockHeight;
        } else {
          // In the rare case the block itself exceeds a full page, add it alone
          pages.add(PageContent(
            content: block.rawHtml,
            chapterIndex: chapterIndex,
            pageNumberInChapter: pages.length + 1,
            chapterTitle: chapterTitle,
          ));
          currentPageBlocks = [];
          currentPageHeight = 0.0;
        }
      }
    }

    // Add remaining content as last page
    if (currentPageBlocks.isNotEmpty) {
      pages.add(PageContent(
        content: currentPageBlocks.join('\n'),
        chapterIndex: chapterIndex,
        pageNumberInChapter: pages.length + 1,
        chapterTitle: chapterTitle,
      ));
    }

    return pages;
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
  bool _isRightToLeftReadingOrder = false;
  Timer? _sliderDwellTimer;
  int? _lastSliderValue;
  bool _isSliderInteracting = false;
  Map<int, String> _chapterContentCache = {};
  Map<int, List<PageContent>> _chapterPagesCache = {};
  int _totalPages = 0;
  int _currentPage = 0;
  late EpubPageCalculator _pageCalculator;
  double _fontSize = EpubPageCalculator.DEFAULT_FONT_SIZE;
  int _totalWordsInBook = 0;
  Map<int, int> _wordsPerChapter = {};
  final Map<int, int> _absolutePageMapping = {};
  int _nextAbsolutePage = 1;

  // Add this getter to ensure valid slider values
  double get _sliderMax => _totalPages > 0 ? _totalPages.toDouble() : 1.0;
  double get _sliderValue => _getCurrentPage().toDouble().clamp(1, _sliderMax);

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

  @override
  void initState() {
    super.initState();
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
    _cleanupCache();
    _isDisposed = true;
    _positionsListener.itemPositions.removeListener(_onScroll);
    _pulseController.dispose();
    _pulseTimer?.cancel();
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
        setState(() {
          _currentPage = newPage;
        });
        _updateMetadata(newPage);
      }
    } else {
      // Handle horizontal/vertical paged mode chapter tracking
      final firstIndex = positions.first.index;
      if (firstIndex != _currentChapterIndex) {
        setState(() {
          _currentChapterIndex = firstIndex;
          _loadSurroundingChapters(firstIndex);
        });
      }

      // Update progress when scrolling within the same chapter
      final page = _calculateCurrentPage();
      if (page != _currentPage && !_isSliderInteracting) {
        setState(() {
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
      // For horizontal mode, use existing page tracking
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
      setState(() {
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

      setState(() {
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

        // Initialize metadata
        final metadata = await _metadataRepository.getMetadata(filePath);
        setState(() {
          _metadata = metadata;
          if (metadata?.lastOpenedPage != null &&
              metadata!.lastOpenedPage > 0) {
            _currentPage = metadata.lastOpenedPage;
          }
        });

        // In vertical mode, preload all chapters
        if (_layoutMode == EpubLayoutMode.vertical) {
          for (int i = 0; i < _flatChapters.length; i++) {
            await _preloadChapter(i);
            await _splitChapterIntoPages(i);
          }
        } else {
          // In horizontal mode, load surrounding chapters
          await _splitChapterIntoPages(_currentChapterIndex);
          await _loadSurroundingChapters(_currentChapterIndex);
        }

        _calculateTotalPages();
        setState(() {
          _isLoading = false;
        });
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
      setState(() {
        _totalPages = _flattenedPages.length;
      });
    } else {
      int total = 0;
      for (var i = 0; i < _flatChapters.length; i++) {
        total += _chapterPagesCache[i]?.length ?? 0;
      }
      setState(() {
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
      // Save current progress before popping
      if (_metadata != null) {
        await _updateMetadata(_currentChapterIndex + 1);
      }
      if (mounted) {
        context.read<ReaderBloc>().add(CloseReader());
        context.read<FileBloc>().add(CloseViewer());
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

  void _handleLayoutChange(EpubLayoutMode mode) {
    setState(() {
      _layoutMode = mode;
    });
    // Re-render the current chapter with new layout
    if (_scrollController.isAttached && mounted) {
      _scrollController.jumpTo(index: _currentChapterIndex);
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
        setState(() {
          _chapterPagesCache[chapterIndex] = pages;
        });
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error splitting chapter $chapterIndex into pages: $e');
      // Add a single page with error message
      if (!_isDisposed) {
        setState(() {
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
                                setState(() {
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Font Size'),
                                        content: StatefulBuilder(
                                          builder: (context, setState) =>
                                              Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Slider(
                                                value: _fontSize,
                                                min: 12.0,
                                                max: 24.0,
                                                divisions: 12,
                                                label: _fontSize
                                                    .round()
                                                    .toString(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _fontSize = value;
                                                  });
                                                },
                                                onChangeEnd: (value) {
                                                  // Update font size and recalculate pages
                                                  _pageCalculator =
                                                      EpubPageCalculator(
                                                    viewportWidth:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    viewportHeight:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .height,
                                                    fontSize: value,
                                                  );
                                                  _chapterPagesCache.clear();
                                                  _loadSurroundingChapters(
                                                      _currentChapterIndex);
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Sample Text',
                                                style: TextStyle(
                                                    fontSize: _fontSize),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
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
                              setState(() {
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
                                            setState(() {
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
                                            setState(() {
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
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight:
                                        ResponsiveConstants.isTablet(context)
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
                                    thumbColor: Theme.of(context).brightness ==
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
                                          ResponsiveConstants.isTablet(context)
                                              ? 8
                                              : 6,
                                    ),
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius:
                                          ResponsiveConstants.isTablet(context)
                                              ? 16
                                              : 12,
                                    ),
                                  ),
                                  child: _totalPages > 0
                                      ? Slider(
                                          value: _sliderValue,
                                          min: 1,
                                          max: _sliderMax,
                                          onChangeStart: (value) {
                                            _sliderDwellTimer?.cancel();
                                            _lastSliderValue = value.toInt();
                                            _isSliderInteracting = true;
                                          },
                                          onChanged: (value) {
                                            final intValue = value.toInt();
                                            if (_lastSliderValue != intValue) {
                                              _sliderDwellTimer?.cancel();
                                              _lastSliderValue = intValue;
                                              setState(() {
                                                _currentPage = intValue;
                                              });
                                              _sliderDwellTimer = Timer(
                                                const Duration(
                                                    milliseconds: 200),
                                                () {
                                                  if (mounted &&
                                                      _lastSliderValue ==
                                                          intValue) {
                                                    _jumpToPage(intValue);
                                                  }
                                                },
                                              );
                                            }
                                          },
                                          onChangeEnd: (value) {
                                            _sliderDwellTimer?.cancel();
                                            final intValue = value.toInt();
                                            _jumpToPage(intValue);
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 200), () {
                                              if (mounted) {
                                                _isSliderInteracting = false;
                                                _lastSliderValue = null;
                                              }
                                            });
                                          },
                                        )
                                      : const SizedBox.shrink(),
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
        controller: PageController(
          initialPage: _currentPage - 1,
          keepPage: true,
        ),
        onPageChanged: (index) {
          if (!_isDisposed && mounted) {
            setState(() {
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
        controller: PageController(
          initialPage: _currentPage - 1,
          keepPage: true,
        ),
        onPageChanged: (index) {
          if (!_isDisposed && mounted) {
            setState(() {
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
      setState(() {
        _showChapters = false;
      });
      return;
    }

    // Toggle UI visibility after handling side widgets
    context.read<ReaderBloc>().add(ToggleUIVisibility());
  }

  Widget _buildPage(PageContent page) {
    return SelectionArea(
      selectionControls: MaterialTextSelectionControls(),
      onSelectionChanged: (selection) {
        setState(() {
          _selectedText = selection?.plainText;
        });
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
              if (page.pageNumberInChapter == 1) ...[
                Text(
                  page.chapterTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF2F2F7)
                            : const Color(0xFF1C1C1E),
                      ),
                ),
                const SizedBox(height: 24),
              ],
              HtmlWidget(
                page.content,
                textStyle: TextStyle(
                  fontSize: _fontSize,
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
        setState(() {
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
    setState(() {
      _highlightedMarker = highlight;
    });

    _pulseTimer?.cancel();
    _pulseController.forward();

    // Pulse for 3 cycles
    _pulseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
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

    setState(() {
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
      setState(() {
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
        setState(() {
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
          setState(() {
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

        setState(() {
          if (!_highlights.containsKey(chapterIndex)) {
            _highlights[chapterIndex] = [];
          }
          _highlights[chapterIndex]!.add(epubHighlight);
        });
      }
    }
  }

  void _handleTextSelection(
      String? selectedText, int chapterIndex, String content) {
    if (selectedText == null || selectedText.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => FloatingSelectionMenu(
        selectedText: selectedText,
        onMenuSelected: (menuType, text) {
          if (menuType == SelectionMenuType.highlight) {
            final startOffset = content.indexOf(text);
            if (startOffset != -1) {
              _addHighlight(
                text,
                chapterIndex,
                startOffset,
                startOffset + text.length,
                Colors.yellow,
              );
            }
            Navigator.pop(context);
          } else if (menuType == SelectionMenuType.askAi) {
            Navigator.pop(context);
            _handleAskAi(text);
          } else if (menuType == SelectionMenuType.audio) {
            // TODO: Implement audio playback
            Navigator.pop(context);
          } else {
            // Handle translate, dictionary, wikipedia, and generateImage
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierColor: Colors.transparent,
              builder: (context) => FullSelectionMenu(
                selectedText: text,
                menuType: menuType,
                onDismiss: () => Navigator.pop(context),
              ),
            );
          }
        },
        onDismiss: () {
          Navigator.pop(context);
        },
        onExpand: () {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => FullSelectionMenu(
              selectedText: selectedText,
              menuType: SelectionMenuType.askAi,
              onDismiss: () => Navigator.pop(context),
            ),
          );
        },
      ),
    );
  }

  Future<void> _jumpToHighlight(EpubHighlight highlight) async {
    final chapterIndex = highlight.highlight.pageNumber - 1;
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;

    await _loadChapter(chapterIndex);

    // Calculate which page contains the highlight
    final pages = _chapterPagesCache[chapterIndex];
    if (pages == null) return;

    int targetPage = 0;
    int accumulatedLength = 0;

    for (int i = 0; i < pages.length; i++) {
      final pageContent = pages[i].content;
      if (accumulatedLength + pageContent.length > highlight.startOffset) {
        targetPage = i;
        break;
      }
      accumulatedLength += pageContent.length;
    }

    // Calculate the vertical offset to center the highlight
    final textBeforeHighlight = pages[targetPage]
        .content
        .substring(0, highlight.startOffset - accumulatedLength);
    final textPainter = TextPainter(
      text: TextSpan(text: textBeforeHighlight),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 48);

    final verticalOffset = textPainter.height;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetAlignment =
        (verticalOffset - (screenHeight * 0.3)) / screenHeight;

    if (_scrollController.isAttached && mounted) {
      await _scrollController.scrollTo(
        index: chapterIndex,
        duration: const Duration(milliseconds: 300),
        alignment: targetAlignment.clamp(0.0, 1.0),
      );
      _startPulsingHighlight(highlight);
    }
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

    setState(() {
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

  Future<void> _jumpToPage(int targetPage) async {
    if (targetPage < 1 || targetPage > _totalPages) return;

    if (_layoutMode == EpubLayoutMode.vertical) {
      // For vertical mode, scroll directly to the target page index (minus one)
      if (_scrollController.isAttached && mounted) {
        await _scrollController.scrollTo(
          index: targetPage - 1,
          duration: const Duration(milliseconds: 300),
        );
      }
      setState(() {
        _currentPage = targetPage;
      });
    } else {
      // For horizontal mode, find the chapter and offset
      int currentPageCount = 0;
      int targetChapterIndex = 0;
      int pageInChapter = 0;

      for (var i = 0; i < _flatChapters.length; i++) {
        final chapterPages = _chapterPagesCache[i]?.length ?? 0;
        if (currentPageCount + chapterPages >= targetPage) {
          targetChapterIndex = i;
          pageInChapter = targetPage - currentPageCount - 1;
          break;
        }
        currentPageCount += chapterPages;
      }

      // Load the target chapter and surrounding chapters
      await _loadSurroundingChapters(targetChapterIndex);

      if (_scrollController.isAttached && mounted) {
        setState(() {
          _currentPage = targetPage;
          _currentChapterIndex = targetChapterIndex;
        });

        // For horizontal mode, update the page view controller
        if (_layoutMode == EpubLayoutMode.horizontal) {
          final pageController = PageController(initialPage: targetPage - 1);
          pageController.jumpToPage(targetPage - 1);
        }
      }
    }
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
}
