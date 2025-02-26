import 'dart:io';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/companion_chat/presentation/widgets/floating_chat_widget.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/core/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:read_leaf/features/library/domain/models/book_metadata.dart';
import 'package:read_leaf/features/library/data/thumbnail_service.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:read_leaf/features/reader/presentation/widgets/reader/floating_selection_menu.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/full_selection_menu.dart';
import 'dart:math' as math;
import 'dart:core';
import 'package:read_leaf/features/reader/presentation/widgets/epub_viewer/epub_page_content.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/reader_settings_menu.dart';
import 'package:read_leaf/features/reader/data/epub_service.dart';
import 'package:read_leaf/features/reader/domain/models/epub_models.dart';
import 'package:uuid/uuid.dart' as uuid;
import 'package:read_leaf/features/reader/presentation/managers/epub_highlight_manager.dart';
import 'package:read_leaf/features/reader/presentation/controllers/epub_layout_controller.dart';

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
  EpubLayoutMode _layoutMode = EpubLayoutMode.longStrip;
  final bool _isRightToLeftReadingOrder = false;
  Timer? _sliderDwellTimer;
  num? _lastSliderValue;
  bool _isSliderInteracting = false;
  final Map<int, String> _chapterContentCache = {};
  final Map<int, List<EpubPageContent>> _chapterPagesCache = {};
  int _totalPages = 0;
  int _currentPage = 1;
  late EpubService _epubService;
  double _fontSize = 23.0; // Use constant directly
  final int _totalWordsInBook = 0;
  final Map<int, int> _wordsPerChapter = {};
  final Map<int, int> _absolutePageMapping = {};
  int _nextAbsolutePage = 1;

  // Add these getters for slider values
  double get _sliderValue =>
      _currentPage.clamp(1, math.max(1, _totalPages)).toDouble();
  double get _sliderMax => math.max(1.0, _totalPages.toDouble());

  // Highlight management
  EpubHighlightManager? _highlightManager;
  EpubHighlight? _activeHighlight;
  late AnimationController _pulseController;
  Animation<double>? _pulseAnimation;
  Timer? _pulseTimer;

  EpubProcessingResult? _processingResult;

  // Helper: Flatten pages across chapters.
  List<EpubPageContent> get _flattenedPages {
    List<EpubPageContent> allPages = [];
    for (int i = 0; i < _flatChapters.length; i++) {
      if (_chapterPagesCache.containsKey(i)) {
        allPages.addAll(_chapterPagesCache[i]!);
      }
    }
    return allPages;
  }

  // Add these member variables near the top of _EPUBViewerScreenState
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
    _epubService = EpubService();
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
    // No need to initialize page calculator here since we'll use the service
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

      // Determine which chapter this page belongs to
      int visibleChapter = -1;
      if (_flattenedPages.isNotEmpty &&
          bestPosition.index < _flattenedPages.length) {
        // If we have flattened pages, get the chapter directly
        visibleChapter = _flattenedPages[bestPosition.index].chapterIndex;
      } else {
        // Otherwise, each item is a chapter
        visibleChapter = bestPosition.index;
      }

      // Update chapter index if changed
      if (visibleChapter >= 0 && visibleChapter != _currentChapterIndex) {
        _safeSetState(() {
          _currentChapterIndex = visibleChapter;
        });
      }

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
      final stopwatch = Stopwatch()..start();

      // Use the EpubService to load the EPUB file
      _processingResult = await _epubService.loadEpub(filePath);
      _epubBook = _processingResult?.book;

      if (_epubBook != null) {
        _flatChapters = _processingResult!.chapters;

        if (_flatChapters.isEmpty) {
          _safeSetState(() {
            _isLoading = false;
          });
          return;
        }

        // Find metadata or create new entry
        final metadata = await _metadataRepository.getMetadata(filePath);

        if (metadata == null) {
          final bookTitle = _epubBook!.Title ?? path.basename(filePath);
          final bookAuthor = _epubBook!.Author ?? 'Unknown Author';

          print('Creating new metadata for $bookTitle');

          final newMetadata = BookMetadata(
            filePath: filePath,
            title: bookTitle,
            author: bookAuthor,
            lastOpenedPage: 1,
            totalPages: 0, // Will be updated after pagination
            readingProgress: 0.0,
            lastReadTime: DateTime.now(),
            fileType: 'epub',
            highlights: [],
            aiConversations: [],
            isStarred: false,
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

        // Initialize based on layout mode
        if (_layoutMode == EpubLayoutMode.longStrip) {
          // For long strip, we just need to load the first few chapters
          for (int i = 0; i < math.min(3, _flatChapters.length); i++) {
            await _preloadChapter(i);
            await _splitChapterIntoPages(i);
          }
          // Continue loading remaining chapters in background
          _loadRemainingChaptersInBackground();
        } else {
          // For paginated modes, start with current chapter
          await _loadSurroundingChapters(_currentChapterIndex);
          // Continue loading others in background
          _loadRemainingChaptersInBackground();
        }

        _calculateTotalPages();
        print(
            'Initial EPUB loading completed in ${stopwatch.elapsedMilliseconds}ms');

        // Show content while continuing to load
        _safeSetState(() {
          _isLoading = false;
        });

        // Update metadata with total pages
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
          });
        }
      }
    } catch (e) {
      print('Error loading EPUB: $e');
      if (!_isDisposed && mounted) {
        Utils.showErrorSnackBar(context, 'Error loading EPUB: $e');
      }
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  // Process all chapters in a background isolate
  void _processChaptersInBackground() {
    // Start loading chapters from the current one, then expand outward
    final orderedChapters = _getChapterLoadingOrder(_currentChapterIndex);

    // Process chapter loading in chunks to avoid blocking UI
    int processedCount = 0;
    const chunkSize = 3; // Process 3 chapters at a time

    Future<void> processNextChunk() async {
      if (processedCount >= orderedChapters.length || _isDisposed) return;

      final stopwatch = Stopwatch()..start();
      final chunk = orderedChapters.skip(processedCount).take(chunkSize);

      for (final chapterIndex in chunk) {
        if (_isDisposed) return;
        await _preloadChapter(chapterIndex);
        await _splitChapterIntoPages(chapterIndex);
      }

      processedCount += chunkSize;
      _calculateTotalPages();

      print(
          'Processed ${math.min(processedCount, orderedChapters.length)}/${orderedChapters.length} chapters in ${stopwatch.elapsedMilliseconds}ms');

      // Schedule next chunk after a short delay to let UI breathe
      if (processedCount < orderedChapters.length && !_isDisposed) {
        Future.delayed(const Duration(milliseconds: 50), processNextChunk);
      }
    }

    // Start processing the first chunk
    processNextChunk();
  }

  // Load remaining chapters in background after showing initial content
  void _loadRemainingChaptersInBackground() {
    // Get all chapter indices except those already loaded
    final loadedChapters = _chapterPagesCache.keys.toSet();
    final chaptersToLoad = List<int>.generate(_flatChapters.length, (i) => i)
        .where((i) => !loadedChapters.contains(i))
        .toList();

    if (chaptersToLoad.isEmpty) return;

    // Process chapter loading in chunks to avoid blocking UI
    int processedCount = 0;
    const chunkSize = 2; // Process 2 chapters at a time

    Future<void> processNextChunk() async {
      if (processedCount >= chaptersToLoad.length || _isDisposed) return;

      final chunk = chaptersToLoad.skip(processedCount).take(chunkSize);

      for (final chapterIndex in chunk) {
        if (_isDisposed) return;
        await _preloadChapter(chapterIndex);
        await _splitChapterIntoPages(chapterIndex);
      }

      processedCount += chunkSize;
      _calculateTotalPages();

      // Schedule next chunk after a short delay to let UI breathe
      if (processedCount < chaptersToLoad.length && !_isDisposed) {
        Future.delayed(const Duration(milliseconds: 100), processNextChunk);
      }
    }

    // Start processing the first chunk after a delay to let UI render first
    Future.delayed(const Duration(milliseconds: 200), processNextChunk);
  }

  // Get an ordered list of chapter indices to load (starting from current, then outward)
  List<int> _getChapterLoadingOrder(int currentIndex) {
    final result = <int>[];

    // Add current chapter first
    result.add(currentIndex);

    // Add chapters in increasing distance from current
    int distance = 1;
    while (result.length < _flatChapters.length) {
      final before = currentIndex - distance;
      final after = currentIndex + distance;

      if (before >= 0) result.add(before);
      if (after < _flatChapters.length) result.add(after);

      distance++;
    }

    // Filter out duplicates and out-of-bounds indices
    return result
        .where((i) => i >= 0 && i < _flatChapters.length)
        .toSet()
        .toList();
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

  void _calculateTotalPages() {
    if (_isDisposed) return;

    // Calculate total pages based on layout mode
    if (_layoutMode == EpubLayoutMode.longStrip) {
      // For long strip mode, each "page" is essentially a chapter
      // So we use the flattened pages count which combines all chapters
      _safeSetState(() {
        _totalPages = _flattenedPages.length > 0
            ? _flattenedPages.length
            : _flatChapters.length;
      });
    } else {
      // For paginated modes (vertical/horizontal), calculate actual pages
      int total = 0;
      for (var i = 0; i < _flatChapters.length; i++) {
        total += _chapterPagesCache[i]?.length ?? 0;
      }

      // Ensure we always have at least 1 page
      _safeSetState(() {
        _totalPages = total > 0 ? total : 1;
      });
    }

    // Debug output total pages
    print('Total pages calculated: $_totalPages for layout mode: $_layoutMode');
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 || index >= _flatChapters.length || _processingResult == null)
      return;

    try {
      // We can't call private methods directly, so we'll use calculatePages which loads content internally
      await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: index,
        viewportWidth: MediaQuery.of(context).size.width,
        viewportHeight: MediaQuery.of(context).size.height,
        fontSize: _fontSize,
      );

      // Get the chapter content from the processing result after it's been loaded
      if (_processingResult!.chapterContents.containsKey(index)) {
        final content = _processingResult!.chapterContents[index]!;

        // Calculate word count
        final wordCount = content.split(RegExp(r'\s+')).length;
        _wordsPerChapter[index] = wordCount;
      }
    } catch (e) {
      print('Error preloading chapter $index: $e');
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

    _chapterPagesCache.removeWhere((key, value) =>
        !chaptersToKeep.contains(key) &&
        key >= 0 &&
        key < _flatChapters.length);
  }

  void _handleLayoutChange(EpubLayoutMode mode) async {
    // Store current mode and progress before changing
    final previousMode = _layoutMode;
    double currentProgress = 0.0;

    // If switching from long strip to paginated mode, save position info
    if (previousMode == EpubLayoutMode.longStrip &&
        (mode == EpubLayoutMode.vertical ||
            mode == EpubLayoutMode.horizontal)) {
      // Store progress from long strip mode
      final positions = _positionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        final firstPos = positions.first;
        if (_flattenedPages.isNotEmpty) {
          currentProgress = firstPos.index / _flattenedPages.length;
        }
      }
    }

    // If switching from paginated mode to long strip mode, save position info
    int targetChapterIndex = _currentChapterIndex;
    if ((previousMode == EpubLayoutMode.vertical ||
            previousMode == EpubLayoutMode.horizontal) &&
        mode == EpubLayoutMode.longStrip) {
      // Remember current chapter when switching to long strip
      targetChapterIndex = _currentChapterIndex;
    }

    _safeSetState(() {
      _isLoading = true;
      _layoutMode = mode;
    });

    try {
      // For major mode change that affects pagination, reset appropriate caches
      if ((previousMode == EpubLayoutMode.longStrip &&
              (mode == EpubLayoutMode.vertical ||
                  mode == EpubLayoutMode.horizontal)) ||
          ((previousMode == EpubLayoutMode.vertical ||
                  previousMode == EpubLayoutMode.horizontal) &&
              mode == EpubLayoutMode.longStrip)) {
        // Reset page calculation
        _absolutePageMapping.clear();
        _nextAbsolutePage = 1;
      }

      // Re-paginate chapters as needed
      await _loadSurroundingChapters(_currentChapterIndex);
      _calculateTotalPages();

      // Reset page controllers
      _verticalPageController = PageController(initialPage: _currentPage - 1);
      _horizontalPageController = PageController(initialPage: _currentPage - 1);

      if (mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
      }

      // Restore position based on the mode transition type
      if (previousMode == EpubLayoutMode.longStrip &&
          (mode == EpubLayoutMode.vertical ||
              mode == EpubLayoutMode.horizontal)) {
        // When switching from long strip to paginated mode, go to proportional page
        final targetPage = math.max(1, (currentProgress * _totalPages).round());
        await _jumpToPage(targetPage);
      } else if ((previousMode == EpubLayoutMode.vertical ||
              previousMode == EpubLayoutMode.horizontal) &&
          mode == EpubLayoutMode.longStrip) {
        // When switching to long strip from paginated mode, go to the chapter
        if (_scrollController.isAttached) {
          await _scrollController.scrollTo(
            index: targetChapterIndex,
            duration: const Duration(milliseconds: 300),
          );
        }
      } else {
        // For other transitions, stay at current page
        await _jumpToPage(_currentPage);
      }
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
    if (_chapterPagesCache.containsKey(chapterIndex) ||
        _processingResult == null) return;

    try {
      // Use the EpubService to calculate pages
      final epubPages = await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: chapterIndex,
        viewportWidth: MediaQuery.of(context).size.width,
        viewportHeight: MediaQuery.of(context).size.height,
        fontSize: _fontSize,
      );

      // Convert EpubPage objects to EpubPageContent objects
      final pages = epubPages
          .map((p) => EpubPageContent(
                content: p.content,
                chapterIndex: p.chapterIndex,
                pageNumberInChapter: p.pageNumberInChapter,
                chapterTitle: p.chapterTitle,
                wordCount: _wordsPerChapter[chapterIndex] ?? 0,
                absolutePageNumber: p.absolutePageNumber,
              ))
          .toList();

      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[chapterIndex] = pages;
        });
        // Update total pages whenever a new chapter is loaded
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error splitting chapter $chapterIndex into pages: $e');
      // Add a single page with error message
      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[chapterIndex] = [
            EpubPageContent(
              content: '<p>Error loading chapter content: $e</p>',
              chapterIndex: chapterIndex,
              pageNumberInChapter: 1,
              chapterTitle: _flatChapters[chapterIndex].Title ??
                  'Chapter ${chapterIndex + 1}',
              absolutePageNumber: 0, // Default value for error page
            )
          ];
        });
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
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_layoutMode == EpubLayoutMode.horizontal)
                      _buildHorizontalLayout()
                    else if (_layoutMode == EpubLayoutMode.vertical)
                      _buildVerticalPagedLayout()
                    else if (_layoutMode == EpubLayoutMode.longStrip)
                      _buildLongStripLayout()
                    else
                      _buildLongStripLayout(),

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
                                showReaderSettingsMenu(
                                  context: context,
                                  filePath: state.file.path,
                                  currentLayoutMode:
                                      convertToReaderLayoutMode(_layoutMode),
                                  onLayoutModeChanged: (mode) {
                                    Navigator.pop(context); // Close the menu

                                    switch (mode) {
                                      case ReaderLayoutMode.vertical:
                                        _handleLayoutChange(
                                            EpubLayoutMode.vertical);
                                        break;
                                      case ReaderLayoutMode.horizontal:
                                        _handleLayoutChange(
                                            EpubLayoutMode.horizontal);
                                        break;
                                      case ReaderLayoutMode.longStrip:
                                        _handleLayoutChange(
                                            EpubLayoutMode.longStrip);
                                        break;
                                      default:
                                        _handleLayoutChange(
                                            EpubLayoutMode.vertical);
                                    }
                                  },
                                  showLongStripOption: true,
                                );
                              },
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_vert,
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
                                            // Handle navigation based on current layout mode
                                            if (_layoutMode ==
                                                EpubLayoutMode.longStrip) {
                                              // Long strip mode uses scroll controller
                                              _scrollController.scrollTo(
                                                index: index,
                                                duration: const Duration(
                                                    milliseconds: 300),
                                              );
                                            } else {
                                              // For paginated modes, find the first page of the chapter
                                              _navigateToChapter(index);
                                            }

                                            // Close chapter menu
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

  Widget _buildPage(EpubPageContent page) {
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
      final calculatedPages = await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: index,
        viewportWidth: MediaQuery.of(context).size.width,
        viewportHeight: MediaQuery.of(context).size.height,
        fontSize: _fontSize,
      );

      // Convert to EpubPageContent objects
      final pages = calculatedPages
          .map((p) => EpubPageContent(
                content: p.content,
                chapterIndex: p.chapterIndex,
                pageNumberInChapter: p.pageNumberInChapter,
                chapterTitle: p.chapterTitle,
                wordCount: _wordsPerChapter[index] ?? 0,
                absolutePageNumber: p.absolutePageNumber,
              ))
          .toList();

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
      _activeHighlight = highlight;
    });

    _pulseTimer?.cancel();
    _pulseController.forward();

    // Pulse for 3 cycles
    _pulseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _safeSetState(() {
          _activeHighlight = null;
        });
        _pulseController.stop();
        _pulseController.reset();
        _pulseTimer = null;
      }
    });
  }

  void _addHighlight(
      String text, int chapterIndex, int pageNumberInChapter, Color color) {
    if (_highlightManager == null) return;

    final highlight = EpubHighlight(
      text: text,
      chapterIndex: chapterIndex,
      pageNumberInChapter: pageNumberInChapter,
      color: color,
    );

    _highlightManager!.addHighlight(highlight);
    _activeHighlight = highlight;

    // Update metadata with a new list
    if (_metadata != null) {
      final exportedHighlights = _highlightManager!.exportToList();

      // Convert to TextHighlight objects for metadata
      final convertedHighlights = exportedHighlights
          .map((map) => TextHighlight(
                text: map['text'] as String,
                pageNumber: (map['chapterIndex'] as int) + 1,
                note: map['note'] as String?,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                    map['createdAt'] as int),
              ))
          .toList();

      final updatedMetadata = _metadata!.copyWith(
        highlights: convertedHighlights,
      );
      _metadataRepository.saveMetadata(updatedMetadata);
      _safeSetState(() {
        _metadata = updatedMetadata;
      });
    }

    // Start pulsing animation
    _startPulsingHighlight(highlight);
  }

  void _removeHighlight(String highlightId) {
    if (_highlightManager == null) return;

    _highlightManager!.removeHighlight(highlightId);

    // Update metadata with the new list
    if (_metadata != null) {
      final exportedHighlights = _highlightManager!.exportToList();

      // Convert to TextHighlight objects for metadata
      final convertedHighlights = exportedHighlights
          .map((map) => TextHighlight(
                text: map['text'] as String,
                pageNumber: (map['chapterIndex'] as int) + 1,
                note: map['note'] as String?,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                    map['createdAt'] as int),
              ))
          .toList();

      final updatedMetadata = _metadata!.copyWith(
        highlights: convertedHighlights,
      );
      _metadataRepository.saveMetadata(updatedMetadata);
      _safeSetState(() {
        _metadata = updatedMetadata;
      });
    }
  }

  Future<void> _loadHighlights() async {
    if (_metadata == null || _isDisposed || _highlightManager == null) return;

    final highlights = _metadata!.highlights;
    final highlightMaps = highlights
        .map((highlight) => {
              'id': const uuid.Uuid().v4(),
              'text': highlight.text,
              'chapterIndex': highlight.pageNumber - 1,
              'pageNumberInChapter': 0, // Default value
              'color': Colors.yellow.value,
              'createdAt': highlight.createdAt.millisecondsSinceEpoch,
              'note': highlight.note,
            })
        .toList();

    _highlightManager!.loadFromList(highlightMaps);
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

                    // Clear caches for recalculation
                    _chapterPagesCache.clear();
                    _absolutePageMapping.clear();
                    _nextAbsolutePage = 1;

                    setState(() {
                      _fontSize = value;
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

  Future<void> _handleChatMessage(String? message,
      {String? selectedText}) async {
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

  // Find and navigate to the first page of a chapter
  void _navigateToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;

    // Find the first page for this chapter
    int firstPageNumber = 0;
    int currentCount = 0;

    for (int i = 0; i < chapterIndex; i++) {
      final chapterPages = _chapterPagesCache[i]?.length ?? 0;
      currentCount += chapterPages;
    }

    // Add 1 because page numbers are 1-based
    firstPageNumber = currentCount + 1;

    // Use appropriate controller based on layout mode
    if (_layoutMode == EpubLayoutMode.vertical) {
      _verticalPageController.jumpToPage(firstPageNumber - 1);
    } else if (_layoutMode == EpubLayoutMode.horizontal) {
      _horizontalPageController.jumpToPage(firstPageNumber - 1);
    }

    // Update state
    _safeSetState(() {
      _currentPage = firstPageNumber;
      _currentChapterIndex = chapterIndex;
    });

    // Ensure the chapter is loaded
    _loadChapter(chapterIndex);
  }

  Widget _buildLongStripLayout() {
    return Container(
      padding: EdgeInsets.only(
        top: ResponsiveConstants.getBottomBarHeight(context),
        bottom: ResponsiveConstants.getBottomBarHeight(context),
      ),
      child: ScrollablePositionedList.builder(
        itemCount: _flattenedPages.length > 0
            ? _flattenedPages.length
            : _flatChapters.length,
        itemBuilder: (context, index) {
          // If we have pages, use them
          if (_flattenedPages.length > 0) {
            if (index < _flattenedPages.length) {
              final page = _flattenedPages[index];
              return _buildPage(page);
            }
            return const SizedBox(height: 50);
          }
          // Otherwise, build a placeholder that loads the chapter when visible
          else if (index < _flatChapters.length) {
            // Load the chapter if not loaded yet
            if (!_chapterPagesCache.containsKey(index)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadChapter(index);
              });

              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }

            // If chapter is loaded, show its first page
            final pages = _chapterPagesCache[index];
            if (pages != null && pages.isNotEmpty) {
              return _buildPage(pages.first);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              alignment: Alignment.center,
              child: Text(
                'Loading chapter ${index + 1}...',
                style: TextStyle(fontSize: _fontSize),
              ),
            );
          }

          return const SizedBox(height: 50);
        },
        itemScrollController: _scrollController,
        itemPositionsListener: _positionsListener,
      ),
    );
  }
}
