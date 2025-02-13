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

enum EpubLayoutMode { vertical, horizontal, facing }

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
  static const double DEFAULT_FONT_SIZE = 13.0;
  static const double LINE_HEIGHT_MULTIPLIER = 1.5;
  static const double PAGE_PADDING = 32.0; // Account for page padding

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
    _viewportWidth =
        viewportWidth - (PAGE_PADDING * 2); // Account for horizontal padding
    _viewportHeight = viewportHeight;
    _fontSize = fontSize;
    _effectiveViewportHeight =
        _viewportHeight - (PAGE_PADDING * 2); // Account for vertical padding
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
    // Create a map to store styles
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

    // Keep the HTML structure but split into manageable blocks
    final blocks = <ContentBlock>[];

    // Split content by paragraphs while preserving HTML
    final paragraphs = html.split(RegExp(r'(?=<p>)|(?=<h[1-6]>)'));

    for (var p in paragraphs) {
      if (p.trim().isEmpty) continue;

      // Determine the appropriate style based on the tag
      String tag = 'p';
      if (p.startsWith('<h1'))
        tag = 'h1';
      else if (p.startsWith('<h2')) tag = 'h2';

      blocks.add(ContentBlock(
        textSpan: TextSpan(
          text: p,
          style: styles[tag],
        ),
        rawHtml: p,
        styles: {'tag': tag},
      ));
    }

    return ParsedContent(
      blocks: blocks,
      styles: styles,
    );
  }

  // Calculate page breaks based on content and viewport
  List<PageContent> _calculatePageBreaks(
    ParsedContent content,
    int chapterIndex,
    String chapterTitle,
  ) {
    final pages = <PageContent>[];
    List<String> currentPageBlocks = [];
    double currentPageHeight = 0;
    double titleHeight = 0;

    // Calculate title height if it will be shown
    if (pages.isEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: chapterTitle,
          style: TextStyle(
            fontSize: _fontSize * 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      titlePainter.layout(maxWidth: _viewportWidth);
      titleHeight = titlePainter.height + 24; // Add spacing after title
    }

    // Account for title in first page
    double availableHeight =
        _effectiveViewportHeight - (pages.isEmpty ? titleHeight : 0);

    for (var block in content.blocks) {
      final blockHeight = _calculateBlockHeight(block.textSpan);

      // If this block would exceed page height, create new page
      if (currentPageHeight + blockHeight > availableHeight &&
          currentPageBlocks.isNotEmpty) {
        pages.add(PageContent(
          content: currentPageBlocks.join('\n'),
          chapterIndex: chapterIndex,
          pageNumberInChapter: pages.length + 1,
          chapterTitle: chapterTitle,
        ));
        currentPageBlocks = [];
        currentPageHeight = 0;
        availableHeight =
            _effectiveViewportHeight; // Reset available height for new page
      }

      currentPageBlocks.add(block.rawHtml);
      currentPageHeight += blockHeight;
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

  // Calculate height of a content block
  double _calculateBlockHeight(TextSpan block) {
    final textPainter = TextPainter(
      text: block,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: _viewportWidth);
    return textPainter.height + 8; // Add some spacing between blocks
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
    );
  }
}

class EPUBViewerScreen extends StatefulWidget {
  const EPUBViewerScreen({super.key});

  @override
  State<EPUBViewerScreen> createState() => _EPUBViewerScreenState();
}

class _EPUBViewerScreenState extends State<EPUBViewerScreen> {
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
  static const int _wordsPerPage = 500; // Approximate words per page

  // Add this getter to ensure valid slider values
  double get _sliderMax => _totalPages > 0 ? _totalPages.toDouble() : 1.0;
  double get _sliderValue =>
      _calculateCurrentPage().toDouble().clamp(1, _sliderMax);

  @override
  void initState() {
    super.initState();
    _initializeReader();
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

    NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    _positionsListener.itemPositions.addListener(_onScroll);
    await _loadEpub();
  }

  @override
  void dispose() {
    _cleanupCache();
    _isDisposed = true;
    _positionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isDisposed) return;

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final firstIndex = positions.first.index;
    if (firstIndex != _currentChapterIndex) {
      if (!_isDisposed) {
        setState(() {
          _currentChapterIndex = firstIndex;
          _loadSurroundingChapters(firstIndex);
        });
      }

      // Update the current page in the bloc and metadata
      if (mounted) {
        final page = _calculateCurrentPage();
        context.read<ReaderBloc>().add(JumpToPage(page));
        _updateMetadata(page);
      }
    }
  }

  int _calculateCurrentPage() {
    int page = 1;

    // Add pages from completed chapters
    for (var i = 0; i < _currentChapterIndex; i++) {
      page += _chapterPagesCache[i]?.length ?? 0;
    }

    // Add pages in current chapter
    if (_chapterPagesCache[_currentChapterIndex] != null) {
      final currentChapterPages = _chapterPagesCache[_currentChapterIndex]!;
      final positions = _positionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        final firstPosition = positions.first;
        final chapterProgress = firstPosition.itemLeadingEdge;
        // Only add partial progress if we're not at the start of the chapter
        if (chapterProgress > 0) {
          page += (currentChapterPages.length * chapterProgress).floor();
        }
      }
    }

    // Ensure page number is within valid range
    return page.clamp(1, _totalPages);
  }

  Future<void> _jumpToPage(int targetPage) async {
    if (targetPage < 1 || targetPage > _totalPages) return;

    int currentPage = 0;
    int targetChapter = 0;
    double targetOffset = 0.0;

    // Find the target chapter and offset
    for (var i = 0; i < _flatChapters.length; i++) {
      final chapterPages = _chapterPagesCache[i]?.length ?? 0;
      if (currentPage + chapterPages >= targetPage) {
        targetChapter = i;
        // Calculate the offset within the chapter
        final pagesIntoChapter = targetPage - currentPage;
        targetOffset = pagesIntoChapter / chapterPages.toDouble();
        break;
      }
      currentPage += chapterPages;
    }

    // Load the target chapter and surrounding chapters
    await _loadSurroundingChapters(targetChapter);

    // Scroll to the target position
    if (_scrollController.isAttached && mounted) {
      await _scrollController.scrollTo(
        index: targetChapter,
        duration: const Duration(milliseconds: 300),
        alignment: targetOffset.clamp(0.0, 1.0),
      );
    }
  }

  Future<void> _updateMetadata(int currentPage) async {
    if (_metadata == null || _isDisposed) return;

    // Ensure currentPage doesn't exceed total pages
    final validatedPage = currentPage.clamp(1, _totalPages);

    // Calculate progress as a percentage between 0.0 and 1.0
    final progress =
        _totalPages > 0 ? (validatedPage / _totalPages).clamp(0.0, 1.0) : 0.0;

    final updatedMetadata = _metadata!.copyWith(
      lastOpenedPage: validatedPage,
      lastReadTime: DateTime.now(),
      readingProgress: progress,
    );

    await _metadataRepository.saveMetadata(updatedMetadata);
    if (!_isDisposed) {
      setState(() {
        _metadata = updatedMetadata;
      });
    }
  }

  Future<void> _loadEpub() async {
    if (_isDisposed) return;

    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

    try {
      final bytes = await state.file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      // Flatten chapters for easier navigation
      final chapters = _flattenChapters(book.Chapters ?? []);

      // Initialize with a reasonable default
      int initialTotalPages = 1;

      // Get or create metadata
      BookMetadata? metadata = _metadataRepository.getMetadata(state.file.path);
      if (metadata == null) {
        metadata = BookMetadata(
          filePath: state.file.path,
          title: book.Title ?? path.basename(state.file.path),
          author: book.Author,
          totalPages: initialTotalPages,
          lastReadTime: DateTime.now(),
          fileType: 'epub',
        );
        await _metadataRepository.saveMetadata(metadata);
      }

      // Get cover image using thumbnail service
      final coverImage =
          await _thumbnailService.getFileThumbnail(state.file.path);

      if (!_isDisposed) {
        setState(() {
          _epubBook = book;
          _flatChapters = chapters;
          _metadata = metadata;
          _coverImage = coverImage;
          _currentChapterIndex = metadata?.lastOpenedPage != null
              ? (metadata!.lastOpenedPage - 1).clamp(0, chapters.length - 1)
              : 0;
          _totalPages = initialTotalPages;
          _isLoading = false;
        });

        // Load initial chapter content for display
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _splitChapterIntoPages(_currentChapterIndex);
          // Start preloading surrounding chapters' page content
          await _loadSurroundingChapters(_currentChapterIndex);
          // Update total pages after initial load
          _updateTotalPages();
        });
      }

      // Scroll to last read position
      if (_currentChapterIndex > 0 &&
          _scrollController.isAttached &&
          !_isDisposed) {
        await _scrollController.scrollTo(
          index: _currentChapterIndex,
          duration: const Duration(milliseconds: 300),
        );
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        Utils.showErrorSnackBar(context, 'Error loading EPUB: $e');
      }
    }
  }

  void _updateTotalPages() {
    if (_isDisposed) return;

    int total = 0;
    for (var pages in _chapterPagesCache.values) {
      total += pages.length;
    }

    if (total > 0 && total != _totalPages) {
      setState(() {
        _totalPages = total;
      });

      // Update metadata with new total pages
      if (_metadata != null) {
        final updatedMetadata = _metadata!.copyWith(totalPages: total);
        _metadataRepository.saveMetadata(updatedMetadata);
        setState(() {
          _metadata = updatedMetadata;
        });
      }
    }
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 || index >= _flatChapters.length) return;
    if (_chapterContentCache.containsKey(index)) return;

    try {
      final chapter = _flatChapters[index];
      final content = chapter.HtmlContent ?? '';
      _chapterContentCache[index] = content;
    } catch (e) {
      print('Error preloading chapter $index: $e');
    }
  }

  void _cleanupCache() {
    // Keep only nearby chapters in memory
    final chaptersToKeep = <int>{
      _currentChapterIndex - 1,
      _currentChapterIndex,
      _currentChapterIndex + 1,
    };

    _chapterContentCache
        .removeWhere((key, value) => !chaptersToKeep.contains(key));
    _chapterPagesCache
        .removeWhere((key, value) => !chaptersToKeep.contains(key));
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
    final content = _chapterContentCache[chapterIndex] ?? '';

    // Split content into words
    final words = content.split(RegExp(r'\s+'));
    final pages = <PageContent>[];

    for (var i = 0; i < words.length; i += _wordsPerPage) {
      final pageWords = words.skip(i).take(_wordsPerPage).join(' ');
      pages.add(PageContent(
        content: pageWords,
        chapterIndex: chapterIndex,
        pageNumberInChapter: pages.length + 1,
        chapterTitle: chapter.Title ?? 'Chapter ${chapterIndex + 1}',
      ));
    }

    _chapterPagesCache[chapterIndex] = pages;
  }

  Future<void> _loadSurroundingChapters(int currentChapterIndex) async {
    final chaptersToLoad = <int>{
      currentChapterIndex - 1,
      currentChapterIndex,
      currentChapterIndex + 1,
    };

    for (final index in chaptersToLoad) {
      if (index >= 0 &&
          index < _flatChapters.length &&
          !_chapterPagesCache.containsKey(index)) {
        await _preloadChapter(index);
        await _splitChapterIntoPages(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_epubBook == null) {
          return const Scaffold(
            body: Center(child: Text('Failed to load EPUB')),
          );
        }

        if (state is! ReaderLoaded) {
          return const Scaffold(
            body: Center(child: Text('Reader not loaded')),
          );
        }

        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        final showUI = state.showUI;

        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              try {
                // Save current progress before popping
                if (_metadata != null) {
                  await _updateMetadata(_currentChapterIndex + 1);
                }
                if (mounted) {
                  context.read<ReaderBloc>().add(CloseReader());
                  context.read<FileBloc>().add(CloseViewer());
                }
              } catch (e) {
                print('Error handling pop: $e');
              }
            }
          },
          child: GestureDetector(
            onTapDown: (details) {
              // Check if tap is outside side widgets
              if (_showChapters) {
                final sideNavWidth =
                    ResponsiveConstants.getSideNavWidth(context);
                if (details.globalPosition.dx > sideNavWidth) {
                  // Close side widgets if tap is outside their area
                  setState(() {
                    _showChapters = false;
                  });
                }
              }
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  // Main content
                  ScrollablePositionedList.builder(
                    itemCount: _flatChapters.length,
                    itemBuilder: (context, index) =>
                        _buildChapter(_flatChapters[index]),
                    itemScrollController: _scrollController,
                    itemPositionsListener: _positionsListener,
                  ),

                  // Top app bar
                  if (showUI)
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                            size: ResponsiveConstants.getIconSize(context),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        title: Text(
                          _epubBook?.Title ?? path.basename(state.file.path),
                          style: TextStyle(
                            fontSize:
                                ResponsiveConstants.getBodyFontSize(context),
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                                  content:
                                      Text('Search coming soon for EPUB files'),
                                ),
                              );
                            },
                            padding: EdgeInsets.all(
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
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
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
                          ),
                          PopupMenuButton<String>(
                            elevation: 8,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
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
                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                    Rect.fromPoints(
                                      button.localToGlobal(Offset.zero),
                                      button.localToGlobal(
                                          button.size.bottomRight(Offset.zero)),
                                    ),
                                    Offset.zero & overlay.size,
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
                                                      EpubLayoutMode.horizontal
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
                                                    : const Color(0xFF1C1C1E))),
                                      ),
                                      PopupMenuItem(
                                        value: ReadingMode.dark,
                                        child: Text('Dark',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E))),
                                      ),
                                      PopupMenuItem(
                                        value: ReadingMode.sepia,
                                        child: Text('Sepia',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E))),
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
                                              Navigator.of(context).pop(false),
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
                                          context
                                              .read<FileBloc>()
                                              .add(RemoveFile(state.file.path));
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
                                        subject: path.basename(state.file.path),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error sharing file: $e')),
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
                        color: Theme.of(context).brightness == Brightness.dark
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
                                        color: Theme.of(context).brightness ==
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
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF8E8E93)
                                            : const Color(0xFF6E6E73),
                                        size: ResponsiveConstants.getIconSize(
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
                                        chapter.Title ?? 'Chapter ${index + 1}',
                                        style: TextStyle(
                                          color: _currentChapterIndex == index
                                              ? Theme.of(context).primaryColor
                                              : Theme.of(context).brightness ==
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
                                          duration:
                                              const Duration(milliseconds: 300),
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

                  // Floating chat widget
                  FloatingChatWidget(
                    character: _characterService.getSelectedCharacter() ??
                        AiCharacter(
                          name: 'Amelia',
                          avatarImagePath:
                              'assets/images/ai_characters/amelia.png',
                          personality: 'A friendly and helpful AI assistant.',
                          summary:
                              'Amelia is a friendly AI assistant who helps readers understand and engage with their books.',
                          scenario:
                              'You are reading with Amelia, who is eager to help you understand and enjoy your book.',
                          greetingMessage:
                              'Hello! I\'m Amelia. How can I help you with your reading today?',
                          exampleMessages: [
                            'Can you explain this passage?',
                            'What are your thoughts on this chapter?',
                            'Help me understand the main themes.'
                          ],
                          characterVersion: '1',
                          tags: ['Default', 'Reading Assistant'],
                          creator: 'ReadLeaf',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                    onSendMessage: _handleChatMessage,
                    bookId: state.file.path,
                    bookTitle:
                        _epubBook?.Title ?? path.basename(state.file.path),
                    keyboardHeight: keyboardHeight,
                    isKeyboardVisible: isKeyboardVisible,
                    key: _floatingChatKey,
                  ),

                  // Add bottom slider
                  if (showUI)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF251B2F).withOpacity(0.95)
                            : const Color(0xFFFAF9F7).withOpacity(0.95),
                        padding: ResponsiveConstants.getContentPadding(context),
                        height: ResponsiveConstants.getBottomBarHeight(context),
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
                                  overlayColor: Theme.of(context).brightness ==
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
                                              const Duration(milliseconds: 200),
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
                                              const Duration(milliseconds: 200),
                                              () {
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChapter(EpubChapter chapter) {
    final chapterIndex = _flatChapters.indexOf(chapter);
    final pages = _chapterPagesCache[chapterIndex];

    if (pages == null) {
      // Schedule page calculation for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChapter(chapterIndex);
      });
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: pages.map((page) => _buildPage(page)).toList(),
    );
  }

  Widget _buildPage(PageContent page) {
    return EpubPageWidget(
      pageContent: page,
      showTitle: page.pageNumberInChapter == 1,
      onSelectionChanged: (text) {
        if (!_isDisposed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed) {
              setState(() {
                _selectedText = text;
              });
            }
          });
        }
      },
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
        _updateTotalPages();
      }
    } catch (e) {
      print('Error calculating pages for chapter $index: $e');
    }
  }
}
