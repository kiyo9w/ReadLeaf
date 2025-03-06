import 'dart:math';
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
import 'package:material_symbols_icons/material_symbols_icons.dart';

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
  late final _epubService = GetIt.I<EpubService>();
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
  double _fontSize = 23.0; // Default value, will be updated from bloc
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

  // Add the side menu functionality
  bool _isSideNavVisible = false;
  final bool _isAppBarVisible = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _tabController;

  // Timer for auto-hiding UI
  Timer? _uiAutoHideTimer;
  // Animation controller for fading UI elements
  late AnimationController _uiAnimationController;
  late Animation<double> _uiOpacityAnimation;

  StreamSubscription? _fontSizeSubscription;

  // Add loading progress variables
  String _loadingMessage = '';
  double _loadingProgress = 0.0;

  void _toggleSideNav() {
    setState(() {
      _isSideNavVisible = !_isSideNavVisible;
      if (_isSideNavVisible && _isSearchPanelVisible) {
        _isSearchPanelVisible = false;
      }
    });
  }

  void _closeSideNav() {
    if (_isSideNavVisible) {
      setState(() {
        _isSideNavVisible = false;
      });
    }
  }

  bool _isSearchPanelVisible = false;

  void _toggleSearchPanel() {
    setState(() {
      _isSearchPanelVisible = !_isSearchPanelVisible;
      if (_isSearchPanelVisible && _isSideNavVisible) {
        _isSideNavVisible = false;
      }
    });
  }

  void _closeSearchPanel() {
    if (_isSearchPanelVisible) {
      setState(() {
        _isSearchPanelVisible = false;
      });
    }
  }

  // Modify the tap handler to work with bloc and handle auto-hide functionality
  void _handleTapGesture() {
    // First check if side nav or search panel is visible
    if (_isSideNavVisible) {
      _closeSideNav();
      return;
    }

    if (_isSearchPanelVisible) {
      _closeSearchPanel();
      return;
    }

    // Close any open side widgets
    if (_showChapters) {
      _safeSetState(() {
        _showChapters = false;
      });
      return;
    }

    // Define tap zones based on screen width
    final width = MediaQuery.of(context).size.width;
    final leftZone = width * 0.3;
    final rightZone = width * 0.7;

    // Get pointer position from last tap event
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position =
        _lastPointerDownPosition ?? renderBox.localToGlobal(Offset.zero);

    // Handle tap zones
    if (position.dx > leftZone && position.dx < rightZone) {
      // Center zone - toggle UI
      _toggleUI();
    } else if (position.dx <= leftZone) {
      // Left zone - previous page
      if (_currentPage > 1) {
        context.read<ReaderBloc>().add(PreviousPage());
        _goToPreviousPage();
      }
    } else {
      // Right zone - next page
      context.read<ReaderBloc>().add(NextPage());
      _goToNextPage();
    }
  }

  // Toggle UI visibility with animation
  void _toggleUI() {
    final state = context.read<ReaderBloc>().state;
    if (state is ReaderLoaded) {
      final bool showUI = state.showUI;

      // Cancel any existing timer
      _uiAutoHideTimer?.cancel();

      if (showUI) {
        // Hide UI - start animation first
        _uiAnimationController.forward().then((_) {
          // After animation completes, update the bloc state
          context.read<ReaderBloc>().add(ToggleUIVisibility());
          _uiAnimationController.reset();
        });
      } else {
        // Show UI - update bloc state first, then schedule auto-hide
        context.read<ReaderBloc>().add(ToggleUIVisibility());
        _scheduleUiAutoHide();
      }
    }
  }

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

    // Initialize controllers with listeners
    _verticalPageController = PageController();
    _horizontalPageController = PageController();

    // Add page change listeners to both controllers
    _verticalPageController.addListener(_handlePageControllerChange);
    _horizontalPageController.addListener(_handlePageControllerChange);

    // Setup book
    _initializeReader();

    // Initialize the tab controller for the side menu
    _tabController = TabController(length: 3, vsync: this);

    // Listen to reader bloc state changes for font size updates
    _fontSizeSubscription = context.read<ReaderBloc>().stream.listen((state) {
      if (mounted && state is ReaderLoaded && state.fontSize != _fontSize) {
        _updateFontSize(state.fontSize);
      }
    });

    // Initialize UI animation controller
    _uiAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _uiOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeInOut,
    ));

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

  // Handle page controller changes to keep both modes in sync
  void _handlePageControllerChange() {
    if (_isDisposed || _isLoading) return;

    // Check which controller triggered the change
    if (_layoutMode == EpubLayoutMode.vertical &&
        _verticalPageController.hasClients) {
      final page = (_verticalPageController.page?.round() ?? 0) + 1;
      if (page != _currentPage) {
        _safeSetState(() {
          _currentPage = page;
        });
        // Update horizontal controller if it exists and isn't the source of change
        if (_horizontalPageController.hasClients &&
            (_horizontalPageController.page?.round() ?? 0) != page - 1) {
          _horizontalPageController.jumpToPage(page - 1);
        }
      }
    } else if (_layoutMode == EpubLayoutMode.horizontal &&
        _horizontalPageController.hasClients) {
      final page = (_horizontalPageController.page?.round() ?? 0) + 1;
      if (page != _currentPage) {
        _safeSetState(() {
          _currentPage = page;
        });
        // Update vertical controller if it exists and isn't the source of change
        if (_verticalPageController.hasClients &&
            (_verticalPageController.page?.round() ?? 0) != page - 1) {
          _verticalPageController.jumpToPage(page - 1);
        }
      }
    }
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

    // Begin book loading and pagination process
    try {
      _safeSetState(() {
        _isLoading = true;
        _loadingMessage = 'Loading book...';
      });

      // Load the book
      await _loadEpub();

      // First load surrounding chapters for initial display
      await _loadSurroundingChapters(_currentChapterIndex);

      // Do initial calculation of total pages (may be incomplete)
      _calculateTotalPages();

      // Update UI to show progress
      _safeSetState(() {
        _loadingMessage = 'Preparing pagination...';
      });

      // Force complete pagination to ensure we have all pages calculated
      await _forceCompletePagination();

      // Now navigate to last read page with complete pagination
      await _navigateToLastReadPage();
    } catch (e) {
      print('Error initializing book: $e');
    } finally {
      _safeSetState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
    }
  }

  @override
  void dispose() {
    if (_metadata != null && !_isDisposed) {
      _updateMetadata(_currentPage);
    }
    _cleanupCache();
    _isDisposed = true;
    _positionsListener.itemPositions.removeListener(_onScroll);
    _pulseController.dispose();
    _pulseTimer?.cancel();
    _sliderDwellTimer?.cancel();
    _floatingMenuTimer?.cancel();
    _fontSizeSubscription?.cancel();
    _verticalPageController.dispose();
    _horizontalPageController.dispose();
    _removeFloatingMenu();
    _uiAutoHideTimer?.cancel();
    _uiAnimationController.dispose();
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
    } else if (_layoutMode == EpubLayoutMode.vertical) {
      // For vertical mode, get the current page from the controller
      if (_verticalPageController.hasClients &&
          _verticalPageController.page != null) {
        // Add 1 because the controller uses 0-indexed pages
        return (_verticalPageController.page!.round() + 1)
            .clamp(1, _totalPages);
      }
      // Fallback to current state if controller is not available
      return _currentPage.clamp(1, math.max(1, _totalPages));
    } else if (_layoutMode == EpubLayoutMode.horizontal) {
      // For horizontal mode, get the current page from the controller
      if (_horizontalPageController.hasClients &&
          _horizontalPageController.page != null) {
        // Add 1 because the controller uses 0-indexed pages
        return (_horizontalPageController.page!.round() + 1)
            .clamp(1, _totalPages);
      }
      // Fallback to current state if controller is not available
      return _currentPage.clamp(1, math.max(1, _totalPages));
    } else {
      // Fallback for any other mode
      if (_totalPages == 0) return 1;
      return _currentPage.clamp(1, _totalPages);
    }
  }

  Future<void> _updateMetadata(int currentPage) async {
    if (_metadata == null || _isDisposed) return;

    // Ensure currentPage doesn't exceed total pages
    final validatedPage = currentPage.clamp(1, math.max(1, _totalPages));

    // Calculate progress as a percentage between 0.0 and 1.0
    final progress =
        _totalPages > 0 ? (validatedPage / _totalPages).clamp(0.0, 1.0) : 0.0;

    // Update metadata with current page and progress
    final updatedMetadata = _metadata!.copyWith(
      lastOpenedPage: validatedPage.toInt(),
      lastReadTime: DateTime.now(),
      readingProgress: progress,
      totalPages: _totalPages, // Ensure total pages is always up to date
    );

    await _metadataRepository.saveMetadata(updatedMetadata);
    if (!_isDisposed) {
      _safeSetState(() {
        _metadata = updatedMetadata;
        // Also ensure _currentPage is properly clamped
        _currentPage = validatedPage.toInt();
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
        final metadata = _metadataRepository.getMetadata(filePath);

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

        // Important: Navigate to the last read page after initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToLastReadPage();
        });
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

  // Navigate to the last read page stored in metadata
  Future<void> _navigateToLastReadPage() async {
    if (_metadata == null) {
      print('Cannot navigate to last read page: metadata not available');
      return;
    }

    // Get the last read page from metadata - don't clamp yet
    final targetPage = _metadata!.lastOpenedPage;

    print('Preparing to navigate to last read page: $targetPage');

    // Wait for all pagination to complete and total pages to be accurate
    await _ensureFullPagination();

    // Now clamp after we have the correct total pages
    final lastPage = targetPage.clamp(1, _totalPages);

    print(
        'Navigating to last read page: $lastPage (original: $targetPage) of $_totalPages');

    // Wait a moment for layout to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // Jump to the page directly
    try {
      if (_layoutMode == EpubLayoutMode.vertical &&
          _verticalPageController.hasClients) {
        _verticalPageController.jumpToPage(lastPage - 1);
        print('Vertical jump complete to page ${lastPage - 1} (0-indexed)');
      } else if (_layoutMode == EpubLayoutMode.horizontal &&
          _horizontalPageController.hasClients) {
        _horizontalPageController.jumpToPage(lastPage - 1);
        print('Horizontal jump complete to page ${lastPage - 1} (0-indexed)');
      } else if (_layoutMode == EpubLayoutMode.longStrip &&
          _scrollController.isAttached) {
        // For long strip mode, use the raw index if within flattened pages range
        final targetIndex = lastPage - 1;

        _scrollController.jumpTo(
            index:
                targetIndex.clamp(0, math.max(0, _flattenedPages.length - 1)));
        print('Long strip jump complete to index $targetIndex');
      }

      // Update UI state
      _safeSetState(() {
        _currentPage = lastPage;
      });
    } catch (e) {
      print('Error jumping to last read page: $e');
    }
  }

  // Make sure full pagination is complete before proceeding
  Future<void> _ensureFullPagination() async {
    print('Ensuring complete pagination before navigation...');

    // Wait for the current pagination to finish first
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if we need to update the total pages first
    if (_flattenedPages.length > _totalPages) {
      _safeSetState(() {
        _totalPages = _flattenedPages.length;
      });
      print('Updated total pages to match flattened pages: $_totalPages');
    }

    // Wait for all chapters to be loaded
    if (_chapterPagesCache.length < _flatChapters.length) {
      print('Not all chapters are cached, forcing complete pagination...');
      await _forceCompletePagination();
    }

    // Final update to total pages based on all available information
    int calculatedTotal = 0;

    // First try to use flattened pages length which should be accurate for long strip
    if (_flattenedPages.isNotEmpty) {
      calculatedTotal = _flattenedPages.length;
    } else {
      // Otherwise sum up all chapter pages
      for (final chapterPages in _chapterPagesCache.values) {
        calculatedTotal += chapterPages.length;
      }
    }

    // Update total pages with max of current and calculated
    if (calculatedTotal > _totalPages) {
      _safeSetState(() {
        _totalPages = calculatedTotal;
      });
      print('Final total pages update: $_totalPages');
    }

    // Print debug info
    _debugPaginationInfo();
  }

  // Initialize the book after loading
  Future<void> _initializeBook() async {
    if (_isDisposed) return;

    try {
      _safeSetState(() {
        _isLoading = true;
        _loadingMessage = 'Loading book...';
      });

      // First load surrounding chapters for initial display
      await _loadSurroundingChapters(_currentChapterIndex);

      // Do initial calculation of total pages (may be incomplete)
      _calculateTotalPages();

      // Update UI to show progress
      _safeSetState(() {
        _loadingMessage = 'Preparing pagination...';
        _isLoading = true;
      });

      // Force complete pagination to ensure we have all pages calculated
      await _forceCompletePagination();

      // Now navigate to last read page with complete pagination
      await _navigateToLastReadPage();
    } catch (e) {
      print('Error initializing book: $e');
    } finally {
      _safeSetState(() {
        _isLoading = false;
        _loadingMessage = '';
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

  // Debug helper for pagination issues
  void _debugPaginationInfo() {
    print('----- PAGINATION DEBUG INFO -----');
    print('Total pages: $_totalPages');
    print('Current page: $_currentPage');
    print('Layout mode: $_layoutMode');
    print('Chapters: ${_flatChapters.length}');
    print('Flattened pages: ${_flattenedPages.length}');
    print('Chapter pages cache: ${_chapterPagesCache.length} chapters cached');

    // Print page counts per chapter
    _chapterPagesCache.forEach((chapterIndex, pages) {
      print('Chapter $chapterIndex: ${pages.length} pages');
    });

    // Print absolute page mapping
    print('Absolute page mapping entries: ${_absolutePageMapping.length}');
    if (_absolutePageMapping.isNotEmpty) {
      final firstEntry = _absolutePageMapping.entries.first;
      final lastEntry = _absolutePageMapping.entries.last;
      print(
          'First mapping: Abs page ${firstEntry.key} -> Chapter ${firstEntry.value}');
      print(
          'Last mapping: Abs page ${lastEntry.key} -> Chapter ${lastEntry.value}');
    }

    print('----------------------------------');
  }

  // Calculate total pages
  void _calculateTotalPages() {
    int totalPages = 0;

    // Count pages from all cached chapters
    for (final pages in _chapterPagesCache.values) {
      totalPages += pages.length;
    }

    // If we have no cached chapters, estimate based on average page count
    if (totalPages == 0 && _flatChapters.isNotEmpty) {
      // Assume approximately 3 pages per chapter if we don't have data
      totalPages = _flatChapters.length * 3;
    }

    // Update total pages
    _safeSetState(() {
      _totalPages = math.max(1, totalPages);
    });

    // Debug pagination info
    _debugPaginationInfo();
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 ||
        index >= _flatChapters.length ||
        _processingResult == null) {
      return;
    }

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
    if (!mounted ||
        _isDisposed ||
        chapterIndex < 0 ||
        chapterIndex >= _flatChapters.length ||
        _chapterPagesCache.containsKey(chapterIndex) ||
        _processingResult == null) {
      return;
    }

    try {
      // Use the EpubService to calculate pages
      final epubPages = await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: chapterIndex,
        viewportWidth: MediaQuery.of(context).size.width,
        viewportHeight: MediaQuery.of(context).size.height,
        fontSize: _fontSize,
      );

      // Check mounted again after the async operation
      if (!mounted || _isDisposed) return;

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

      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _chapterPagesCache[chapterIndex] = pages;
        });
        // Update total pages whenever a new chapter is loaded
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error splitting chapter $chapterIndex into pages: $e');
      // Add a single page with error message only if still mounted
      if (!_isDisposed && mounted) {
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
              onTap: _handleTapGesture,
              behavior: HitTestBehavior.deferToChild,
              child: Scaffold(
                key: _scaffoldKey,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    // Content layer
                    if (_isLoading)
                      _buildLoadingIndicator()
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
                      // Top AppBar with fade animation
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: FadeTransition(
                          opacity: _uiOpacityAnimation,
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
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) {
                                    NavScreen.globalKey.currentState
                                        ?.hideNavBar(false);
                                  }
                                });
                              },
                            ),
                            title: Text(
                              _epubBook?.Title ??
                                  path.basename(state.file.path),
                              style: TextStyle(
                                fontSize: ResponsiveConstants.getBodyFontSize(
                                    context),
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
                                  size:
                                      ResponsiveConstants.getIconSize(context),
                                ),
                                onPressed: () {
                                  _toggleSearchPanel();
                                },
                                padding: EdgeInsets.all(
                                    ResponsiveConstants.isTablet(context)
                                        ? 12
                                        : 8),
                              ),
                              IconButton(
                                icon: Icon(Symbols.thumbnail_bar,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFF2F2F7)
                                        : const Color(0xFF1C1C1E),
                                    size: ResponsiveConstants.getIconSize(
                                        context),
                                    fill: 0.25),
                                padding: EdgeInsets.all(
                                    ResponsiveConstants.isTablet(context)
                                        ? 12
                                        : 8),
                                onPressed: _toggleSideNav,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  size:
                                      ResponsiveConstants.getIconSize(context),
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
                                  size:
                                      ResponsiveConstants.getIconSize(context),
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
                      ),

                      // Side navigation panel with tabs
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        top: 0,
                        bottom: 0,
                        left: _isSideNavVisible
                            ? 0
                            : -ResponsiveConstants.getSideNavWidth(context),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            if (details.delta.dx < 0) {
                              // Only handle left swipes
                              _closeSideNav();
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
                                          _tabController?.index == 0
                                              ? 'Chapters'
                                              : _tabController?.index == 1
                                                  ? 'Bookmarks'
                                                  : 'Pages',
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
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E),
                                            size:
                                                ResponsiveConstants.getIconSize(
                                                    context),
                                          ),
                                          onPressed: _closeSideNav,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tab bar
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF2C2C2E)
                                              : const Color(0xFFF8F1F1),
                                        ),
                                      ),
                                    ),
                                    child: TabBar(
                                      controller: _tabController,
                                      tabs: const [
                                        Tab(
                                          icon: Icon(Icons.menu_book_outlined,
                                              size: 20),
                                          text: 'Chapters',
                                        ),
                                        Tab(
                                          icon: Icon(Icons.bookmark_outline,
                                              size: 20),
                                          text: 'Bookmarks',
                                        ),
                                        Tab(
                                          icon: Icon(Icons.grid_view, size: 20),
                                          text: 'Pages',
                                        ),
                                      ],
                                      labelColor:
                                          Theme.of(context).colorScheme.primary,
                                      unselectedLabelColor:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF8E8E93)
                                              : const Color(0xFF6E6E73),
                                      indicatorColor:
                                          Theme.of(context).colorScheme.primary,
                                      indicatorWeight: 3,
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      unselectedLabelStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      labelPadding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                  ),

                                  // Tab content
                                  Expanded(
                                    child: Container(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF352A3B)
                                              .withOpacity(0.5)
                                          : const Color(0xFFF8F1F1)
                                              .withOpacity(0.5),
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          // Chapters tab (Outline view)
                                          OutlineView(
                                            outlines: _createOutlineItems(),
                                            currentPage: _currentPage,
                                            totalPages: _totalPages,
                                            onItemTap: (item) {
                                              _navigateToChapter(
                                                  item.pageNumber - 1);
                                              _closeSideNav();
                                            },
                                          ),

                                          // Bookmarks tab (Markers view)
                                          MarkersView(
                                            markers: _createMarkerItems(),
                                            currentPage: _currentPage,
                                            totalPages: _totalPages,
                                            onItemTap: (marker) {
                                              // Navigate to the page where the highlight exists
                                              _jumpToPage(marker.pageNumber);
                                              _closeSideNav();
                                            },
                                            onDeleteMarker: (marker) {
                                              // Delete the highlight
                                              _removeHighlight(marker.id);
                                            },
                                          ),

                                          // Pages tab (Thumbnails view)
                                          ThumbnailsView(
                                            totalPages: _totalPages,
                                            currentPage: _currentPage,
                                            onPageSelected: (pageNum) {
                                              _jumpToPage(pageNum);
                                              _closeSideNav();
                                            },
                                            getThumbnail: (page) {
                                              return Container(
                                                width: double.infinity,
                                                height: double.infinity,
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: Text(
                                                    'Page $page',
                                                    style: const TextStyle(
                                                        color: Colors.black54),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Search panel
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        top: 0,
                        bottom: 0,
                        left: _isSearchPanelVisible
                            ? 0
                            : -ResponsiveConstants.getSideNavWidth(context),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            if (details.delta.dx < 0) {
                              _closeSearchPanel();
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
                                          'Search',
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
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E),
                                            size:
                                                ResponsiveConstants.getIconSize(
                                                    context),
                                          ),
                                          onPressed: _closeSearchPanel,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Search in book...',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        // TODO: Implement search functionality
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Search coming soon for EPUB files'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'Search feature coming soon',
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Overlay to close side nav when tapping outside
                      if (_isSideNavVisible)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _closeSideNav,
                            child: Container(
                              color: Colors
                                  .transparent, // Changed from black with opacity to transparent
                            ),
                          ),
                        ),

                      // Overlay to close search panel when tapping outside
                      if (_isSearchPanelVisible)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _closeSearchPanel,
                            child: Container(
                              color: Colors
                                  .transparent, // Changed from black with opacity to transparent
                            ),
                          ),
                        ),

                      // Bottom bar
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
                              // Add bookmark button
                              IconButton(
                                icon: Icon(
                                  Icons.bookmark_add_outlined,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  size: 22,
                                ),
                                onPressed: () => _addBookmark(_currentPage),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              const SizedBox(width: 8),

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
        top: ResponsiveConstants.getReaderPageTopPadding(context),
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
        top: ResponsiveConstants.getReaderPageTopPadding(context),
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
    // Simply delegate to _handleTapGesture for consistent behavior
    _handleTapGesture();
  }

  Widget _buildPage(EpubPageContent page) {
    // Check if the content is a chapter title (usually at the start of chapters)
    bool isChapterTitle = false;
    String content = page.content;

    // Make chapter titles centered if content contains heading tags
    if (content.contains('<h1>') ||
        content.contains('<h2>') ||
        content.contains('<h3>')) {
      content = content.replaceAllMapped(
          RegExp(r'<(h[1-3])[^>]*>(.*?)<\/\1>', dotAll: true),
          (match) =>
              '<${match.group(1)} style="text-align: center;">${match.group(2)}</${match.group(1)}>');
      isChapterTitle = true;
    }

    // Add some basic styling to the content for better formatting
    content = '''
    <div style="height: 100%; display: flex; flex-direction: column; justify-content: flex-start;">
      $content
    </div>
    ''';

    // Use a height slightly smaller than screen height to avoid cropping
    final screenHeight = MediaQuery.of(context).size.height;
    final contentHeight = screenHeight -
        (ResponsiveConstants.getBottomBarHeight(context) * 2) -
        (isChapterTitle ? 60.0 : 25.0);

    return Container(
      width: MediaQuery.of(context).size.width,
      height: contentHeight,
      padding: EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: isChapterTitle ? 20.0 : 10.0,
      ),
      child: SelectionArea(
        onSelectionChanged: (selection) {
          final selectedText = selection?.plainText ?? '';
          _handleTextSelectionChange(
              selectedText.isNotEmpty ? selectedText : null);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTapGesture,
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
            // Use HtmlWidget for formatted text, with Text as fallback
            child: HtmlWidget(
              content,
              customStylesBuilder: (element) {
                // Default styles to preserve formatting from our enhanced HTML
                if (element.attributes.containsKey('style')) {
                  // If the element already has style attributes from our HTML formatting,
                  // we don't need to override them
                  return null;
                }

                if (element.localName == 'p') {
                  return {
                    'text-align': 'justify',
                    'text-indent': '1.5em',
                    'margin-bottom': '0.5em',
                    'padding': '0',
                    'line-height': '1.5'
                  };
                }
                if (element.localName == 'h1') {
                  return {
                    'text-align': 'center',
                    'margin-top': '1em',
                    'margin-bottom': '0.5em',
                    'font-weight': 'bold',
                    'font-size': '1.5em',
                  };
                }
                if (element.localName == 'h2') {
                  return {
                    'text-align': 'center',
                    'margin-top': '0.8em',
                    'margin-bottom': '0.5em',
                    'font-weight': 'bold',
                    'font-size': '1.4em',
                  };
                }
                if (element.localName?.startsWith('h') == true) {
                  return {
                    'font-weight': 'bold',
                    'margin-top': '0.6em',
                    'margin-bottom': '0.4em',
                    'font-size': '1.2em',
                  };
                }
                if (element.localName == 'b' || element.localName == 'strong') {
                  return {'font-weight': 'bold'};
                }
                if (element.localName == 'i' || element.localName == 'em') {
                  return {'font-style': 'italic'};
                }
                if (element.localName == 'u') {
                  return {'text-decoration': 'underline'};
                }
                if (element.localName == 'blockquote') {
                  return {
                    'font-style': 'italic',
                    'margin-left': '2em',
                    'margin-right': '2em',
                    'margin-top': '0.5em',
                    'margin-bottom': '0.5em',
                  };
                }
                if (element.localName == 'div') {
                  // Default styling for divs
                  if (element.classes.contains('centered') ||
                      element.classes.contains('center')) {
                    return {
                      'text-align': 'center',
                      'width': '100%',
                      'margin-top': '0.5em',
                      'margin-bottom': '0.5em',
                    };
                  }
                  return {'width': '100%'};
                }
                if (element.localName == 'hr') {
                  return {
                    'width': '50%',
                    'margin': '1em auto',
                    'border-top': '1px solid #ccc',
                  };
                }
                return null;
              },
              textStyle: TextStyle(
                fontSize: _fontSize,
                height: 1.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF1C1C1E),
              ),
              onLoadingBuilder: (context, element, loadingProgress) => Center(
                child: CircularProgressIndicator(value: loadingProgress),
              ),
              onErrorBuilder: (context, element, error) => Text(
                // Fallback to plain text if HTML rendering fails
                page.plainText ??
                    content.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                style: TextStyle(
                  fontSize: _fontSize,
                  height: 1.3,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF2F2F7)
                      : const Color(0xFF1C1C1E),
                ),
                textAlign: TextAlign.justify,
              ),
              // Fill the entire page
              renderMode: RenderMode.column,
            ),
          ),
        ),
      ),
    );
  }

  // Helper to get the HTML widget factory with enhanced styling support
  WidgetFactory? _getHtmlWidgetFactory() {
    return null; // Use the default factory
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

      // Convert EpubPage objects to EpubPageContent objects with plain text
      final pages = calculatedPages.map((p) {
        // Extract plain text by removing HTML tags
        final plainText = p.content.replaceAll(RegExp(r'<[^>]*>'), '').trim();

        return EpubPageContent(
          content: p.content,
          chapterIndex: p.chapterIndex,
          pageNumberInChapter: p.pageNumberInChapter,
          chapterTitle: p.chapterTitle,
          wordCount: _wordsPerChapter[index] ?? 0,
          absolutePageNumber: p.absolutePageNumber,
          plainText: plainText, // Add the plain text
        );
      }).toList();

      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[index] = pages;
        });
        // Update total pages whenever a new chapter is loaded
        _calculateTotalPages();
      }
    } catch (e) {
      print('Error calculating pages for chapter $index: $e');
      // Add a single page with error message
      if (!_isDisposed) {
        _safeSetState(() {
          _chapterPagesCache[index] = [
            EpubPageContent(
              content: '<p>Error loading chapter content: $e</p>',
              chapterIndex: index,
              pageNumberInChapter: 1,
              chapterTitle:
                  _flatChapters[index].Title ?? 'Chapter ${index + 1}',
              absolutePageNumber: 0, // Default value for error page
              plainText: 'Error loading chapter content: $e',
            )
          ];
        });
      }
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
    if (_layoutMode == EpubLayoutMode.longStrip) {
      return _calculateCurrentPageInLongStrip();
    } else if (_layoutMode == EpubLayoutMode.vertical) {
      if (_verticalPageController.hasClients) {
        return (_verticalPageController.page?.round() ?? 0) + 1;
      }
    } else if (_layoutMode == EpubLayoutMode.horizontal) {
      if (_horizontalPageController.hasClients) {
        return (_horizontalPageController.page?.round() ?? 0) + 1;
      }
    }

    return _currentPage;
  }

  Future<void> _jumpToPage(num targetPage) async {
    // Simple boundary check and conversion to int - log the original value
    final originalPage = targetPage;
    final int page = targetPage.clamp(1, _totalPages).toInt();

    // Log for debugging
    if (originalPage != page) {
      print(
          'Page request clamped from $originalPage to $page (total: $_totalPages)');
    }

    // Update state right away
    _safeSetState(() {
      _currentPage = page;
    });

    try {
      // Handle navigation based on layout mode
      if (_layoutMode == EpubLayoutMode.vertical &&
          _verticalPageController.hasClients) {
        _verticalPageController.animateToPage(
          page - 1, // Convert to 0-indexed
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (_layoutMode == EpubLayoutMode.horizontal &&
          _horizontalPageController.hasClients) {
        _horizontalPageController.animateToPage(
          page - 1, // Convert to 0-indexed
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (_layoutMode == EpubLayoutMode.longStrip &&
          _scrollController.isAttached) {
        // For long strip, find the closest chapter
        int index = 0;

        if (_flattenedPages.isNotEmpty && page <= _flattenedPages.length) {
          index = page - 1;
        } else {
          // Estimate based on total progress
          double progress = _totalPages > 0 ? page / _totalPages : 0;
          index = (progress * _flatChapters.length).floor();
          index = index.clamp(0, _flatChapters.length - 1);
        }

        _scrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
        );
      }

      // Update any metadata needed after navigation
      await _updateMetadata(page);
    } catch (e) {
      print('Error jumping to page: $e');
    }
  }

  // Update font size and recalculate pages
  Future<void> _updateFontSize(double newFontSize) async {
    if (!mounted || _fontSize == newFontSize) return;

    _safeSetState(() {
      _isLoading = true;
      _fontSize = newFontSize;
    });

    try {
      double oldProgress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

      // Clear caches for recalculation
      _chapterPagesCache.clear();
      _absolutePageMapping.clear();
      _nextAbsolutePage = 1;

      for (int i = 0; i < _flatChapters.length; i++) {
        if (!mounted) {
          return; // Check mounted state before processing each chapter
        }
        await _splitChapterIntoPages(i);
      }

      if (!mounted) return;
      _calculateTotalPages();

      int newCurrentPage =
          _totalPages > 0 ? (oldProgress * _totalPages).round() : 1;
      newCurrentPage = newCurrentPage.clamp(1, _totalPages);

      _verticalPageController = PageController(initialPage: newCurrentPage - 1);
      _horizontalPageController =
          PageController(initialPage: newCurrentPage - 1);

      if (mounted) {
        _safeSetState(() {
          _currentPage = newCurrentPage;
          _isLoading = false;
        });
      }

      if (!mounted) return;
      await _jumpToPage(newCurrentPage);
      await _updateMetadata(
          newCurrentPage); // Update metadata after pagination changes
    } catch (e) {
      print('Error updating font size: $e');
      if (mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
      }
    }
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

    // Find the first page for this chapter based on flattened pages
    int pageNumber = 1; // Default to first page

    // Look through all the flattened pages to find the first one from this chapter
    if (_flattenedPages.isNotEmpty) {
      for (int i = 0; i < _flattenedPages.length; i++) {
        if (_flattenedPages[i].chapterIndex == chapterIndex) {
          pageNumber = i + 1; // +1 because page numbers are 1-based
          break;
        }
      }
    } else {
      // If flattened pages aren't available, calculate based on chapter cache
      int currentCount = 0;
      for (int i = 0; i < chapterIndex; i++) {
        currentCount += _chapterPagesCache[i]?.length ?? 0;
      }
      pageNumber = currentCount + 1;
    }

    print('Navigating to chapter $chapterIndex at page $pageNumber');

    // Based on layout mode, use the appropriate navigation method
    if (_layoutMode == EpubLayoutMode.longStrip) {
      if (_scrollController.isAttached) {
        _scrollController.scrollTo(
          index: pageNumber - 1,
          duration: const Duration(milliseconds: 300),
        );
      }
    } else if (_layoutMode == EpubLayoutMode.vertical) {
      _verticalPageController.animateToPage(
        pageNumber - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_layoutMode == EpubLayoutMode.horizontal) {
      _horizontalPageController.animateToPage(
        pageNumber - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Update state
    _safeSetState(() {
      _currentPage = pageNumber;
      _currentChapterIndex = chapterIndex;
    });

    // Ensure the chapter is loaded
    _loadChapter(chapterIndex);
  }

  Widget _buildLongStripLayout() {
    return Container(
      child: ScrollablePositionedList.builder(
        itemCount: _flattenedPages.isNotEmpty
            ? _flattenedPages.length
            : _flatChapters.length,
        itemBuilder: (context, index) {
          // If we have pages, use them
          if (_flattenedPages.isNotEmpty) {
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
                height: MediaQuery.of(context).size.height,
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

  // Helper method to create outline items from EPUB chapters
  List<OutlineItem> _createOutlineItems() {
    List<OutlineItem> items = [];

    for (int i = 0; i < _flatChapters.length; i++) {
      final chapter = _flatChapters[i];

      // Calculate actual page number for this chapter
      int pageNumber = 1;
      if (_flattenedPages.isNotEmpty) {
        // Find the first page of this chapter in flattened pages
        for (int j = 0; j < _flattenedPages.length; j++) {
          if (_flattenedPages[j].chapterIndex == i) {
            pageNumber = j + 1;
            break;
          }
        }
      } else {
        // If flattened pages not ready, estimate based on chapter cache
        int currentCount = 0;
        for (int j = 0; j < i; j++) {
          currentCount += _chapterPagesCache[j]?.length ?? 0;
        }
        pageNumber = currentCount + 1;
      }

      // Create outline item with the chapter title and subtitle
      items.add(OutlineItem(
        title: chapter.Title ?? 'Chapter ${i + 1}',
        subtitle: '', // Could put estimated page count here if desired
        pageNumber: pageNumber,
        level: 0, // Top level for now, could parse nested chapters later
      ));
    }

    return items;
  }

  // Helper method to create marker items from highlights
  List<MarkerItem> _createMarkerItems() {
    if (_metadata == null) return [];

    return _metadata!.highlights.map((h) {
      return MarkerItem(
        id: const uuid.Uuid().v4(), // Generate a new UUID for each highlight
        text: h.text,
        pageNumber: h.pageNumber,
        color: Colors.yellow,
        createdAt: h.createdAt,
        note: h.note,
      );
    }).toList();
  }

  // Add bookmark functionality
  void _addBookmark(int pageNumber) {
    if (_metadata == null) return;

    // Get current flattened page if possible
    String pageContent = '';
    if (_flattenedPages.isNotEmpty && pageNumber <= _flattenedPages.length) {
      pageContent = _flattenedPages[pageNumber - 1].content;
      // Extract first few characters as a preview
      pageContent = _extractTextPreview(pageContent);
    }

    // Create a new highlight that serves as a bookmark
    final bookmark = TextHighlight(
      text:
          pageContent.isNotEmpty ? pageContent : 'Bookmark at page $pageNumber',
      pageNumber: pageNumber,
      createdAt: DateTime.now(),
      note: 'Bookmark',
    );

    // Add to existing highlights
    final updatedHighlights = List<TextHighlight>.from(_metadata!.highlights)
      ..add(bookmark);

    // Update metadata
    final updatedMetadata = _metadata!.copyWith(
      highlights: updatedHighlights,
    );

    // Save and update state
    _metadataRepository.saveMetadata(updatedMetadata);
    _safeSetState(() {
      _metadata = updatedMetadata;
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Helper to extract preview text from HTML content
  String _extractTextPreview(String htmlContent) {
    // Simple algorithm to extract text, can be improved
    String text = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with one
        .trim();

    // Limit length
    if (text.length > 100) {
      text = '${text.substring(0, 97)}...';
    }

    return text;
  }

  // Function to schedule UI auto-hide
  void _scheduleUiAutoHide() {
    // Cancel any existing timer
    _uiAutoHideTimer?.cancel();

    final state = context.read<ReaderBloc>().state;
    if (state is ReaderLoaded && state.showUI) {
      // Only start timer if UI is visible
      _uiAutoHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          // Animate UI out
          _uiAnimationController.forward().then((_) {
            // After animation completes, update the bloc state
            context.read<ReaderBloc>().add(ToggleUIVisibility());

            // Reset animation controller for next time
            _uiAnimationController.reset();
          });
        }
      });
    }
  }

  // Navigate to the next page
  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _safeSetState(() {
        _currentPage++;
      });

      // Update page view if using horizontal layout
      if (_layoutMode == EpubLayoutMode.horizontal) {
        _horizontalPageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // Navigate to the previous page
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _safeSetState(() {
        _currentPage--;
      });

      // Update page view if using horizontal layout
      if (_layoutMode == EpubLayoutMode.horizontal) {
        _horizontalPageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _changeLayoutMode(EpubLayoutMode mode) async {
    if (_layoutMode == mode) return;

    // Get current page before changing mode
    final currentPage = _currentPage;
    final previousMode = _layoutMode;

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
        // Clear caches since pagination is different between these modes
        _chapterPagesCache.clear();
        _absolutePageMapping.clear();
        _nextAbsolutePage = 1;
      }

      // Rebuild pages with new layout mode
      await _loadSurroundingChapters(_currentChapterIndex);
      _calculateTotalPages();

      // Wait for layout to complete
      await Future.delayed(Duration(milliseconds: 50));

      // Jump to the same position in the new mode
      if (currentPage > 0) {
        await _jumpToPage(currentPage);
      }
    } catch (e) {
      print('Error changing layout mode: $e');
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });

      // Save the new mode preference
      await _updateMetadata(_currentPage);
    }
  }

  // Calculate current page based on scroll position in long strip mode
  int _calculateCurrentPageInLongStrip() {
    if (_flattenedPages.isEmpty) {
      return 1;
    }

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return 1;
    }

    // Sort positions by how visible they are
    final visiblePositions = positions.toList()
      ..sort((a, b) {
        // First sort by visibility percentage
        final aVisibility = a.itemLeadingEdge < 0
            ? 0.0
            : (1.0 - a.itemLeadingEdge) *
                (a.itemTrailingEdge > 1.0 ? 1.0 : a.itemTrailingEdge);
        final bVisibility = b.itemLeadingEdge < 0
            ? 0.0
            : (1.0 - b.itemLeadingEdge) *
                (b.itemTrailingEdge > 1.0 ? 1.0 : b.itemTrailingEdge);

        // If visibility is significantly different, use that
        if ((aVisibility - bVisibility).abs() > 0.1) {
          return bVisibility.compareTo(aVisibility);
        }

        // Otherwise, prefer the item that's more in view from the top
        return a.itemLeadingEdge.compareTo(b.itemLeadingEdge);
      });

    // Get the most visible position
    final position = visiblePositions.first;

    // Add 1 because positions are 0-indexed
    return position.index + 1;
  }

  // Force complete pagination of the entire book
  Future<void> _forceCompletePagination() async {
    print('Forcing complete pagination of all chapters...');
    _safeSetState(() {
      _isLoading = true;
    });

    try {
      // Clear any existing cached pagination
      _chapterPagesCache.clear();
      _absolutePageMapping.clear();
      _nextAbsolutePage = 1;

      // Get dimensions for pagination
      final viewportSize = MediaQuery.of(context).size;

      // Force loading of all chapters in sequence
      for (int i = 0; i < _flatChapters.length; i++) {
        // Load each chapter explicitly
        if (!_chapterPagesCache.containsKey(i)) {
          print('Paginating chapter $i of ${_flatChapters.length}');

          try {
            // Make sure the chapter content is loaded
            await _loadChapter(i);

            // Update progress periodically
            _safeSetState(() {
              _loadingProgress = (i + 1) / _flatChapters.length;
              _loadingMessage =
                  'Paginating chapter ${i + 1}/${_flatChapters.length}';
            });
          } catch (e) {
            print('Error paginating chapter $i: $e');
          }
        }
      }

      // Calculate the total page count
      int totalPages = 0;

      // First check if we have flattened pages for long strip mode
      final flattenedPages = _flattenedPages;
      if (flattenedPages.isNotEmpty) {
        totalPages = flattenedPages.length;
      } else {
        // Otherwise sum up all chapter pages
        for (final chapterPages in _chapterPagesCache.values) {
          totalPages += chapterPages.length;
        }
      }

      // Ensure we always have at least one page
      totalPages = math.max(1, totalPages);

      // Update the total pages state
      _safeSetState(() {
        _totalPages = totalPages;
      });

      print('Full pagination complete: $_totalPages total pages');
    } catch (e) {
      print('Error during complete pagination: $e');
    } finally {
      _safeSetState(() {
        _isLoading = false;
        _loadingProgress = 1.0;
      });
    }
  }

  // Build the loading indicator widget
  Widget _buildLoadingIndicator() {
    // Get colors from the current theme
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _loadingMessage.isNotEmpty ? _loadingMessage : 'Loading...',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_loadingProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${(_loadingProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Add these adapter classes near the top of the file

// Adapter class for OutlineItem
class OutlineItem {
  final String title;
  final String subtitle;
  final int pageNumber;
  final int level;

  OutlineItem({
    required this.title,
    required this.subtitle,
    required this.pageNumber,
    required this.level,
  });
}

// Adapter class for MarkerItem
class MarkerItem {
  final String id;
  final String text;
  final int pageNumber;
  final Color color;
  final DateTime createdAt;
  final String? note;

  MarkerItem({
    required this.id,
    required this.text,
    required this.pageNumber,
    required this.color,
    required this.createdAt,
    this.note,
  });
}

// Update the OutlineView widget to work with EPUB chapters
class OutlineView extends StatelessWidget {
  final List<OutlineItem> outlines;
  final int currentPage;
  final int totalPages;
  final Function(OutlineItem) onItemTap;

  const OutlineView({
    super.key,
    required this.outlines,
    required this.currentPage,
    required this.totalPages,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (outlines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8E8E93).withOpacity(0.6)
                  : const Color(0xFF6E6E73).withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No chapters found',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF1C1C1E),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This document has no table of contents',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF6E6E73),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Find current chapter index
    int currentChapterIndex = -1;
    for (int i = 0; i < outlines.length; i++) {
      if (outlines[i].pageNumber <= currentPage &&
          (i == outlines.length - 1 ||
              outlines[i + 1].pageNumber > currentPage)) {
        currentChapterIndex = i;
        break;
      }
    }
    if (currentChapterIndex == -1 && outlines.isNotEmpty) {
      currentChapterIndex = 0;
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: outlines.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = outlines[index];
        final isCurrentChapter = index == currentChapterIndex;

        // Create proper indentation based on chapter level
        double leftPadding = 16.0 + (item.level * 16.0);

        return InkWell(
          onTap: () => onItemTap(item),
          child: Container(
            decoration: BoxDecoration(
              color: isCurrentChapter
                  ? (Theme.of(context).colorScheme.primary.withOpacity(0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Padding(
              padding: EdgeInsets.fromLTRB(leftPadding, 14, 16, 14),
              child: Row(
                children: [
                  // Left indicator for current chapter
                  if (isCurrentChapter)
                    Container(
                      width: 4,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else
                    const SizedBox(width: 16),

                  // Chapter title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: isCurrentChapter
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                            fontSize: 15,
                            fontWeight: isCurrentChapter
                                ? FontWeight.w600
                                : FontWeight.w400,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page number
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentChapter
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF8F1F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.pageNumber}',
                      style: TextStyle(
                        color: isCurrentChapter
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFAA96B6)
                                : const Color(0xFF6E6E73),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
}

// Update the MarkersView widget to work with EPUB highlights
class MarkersView extends StatelessWidget {
  final List<MarkerItem> markers;
  final int currentPage;
  final int totalPages;
  final Function(MarkerItem) onItemTap;
  final Function(MarkerItem) onDeleteMarker;

  const MarkersView({
    super.key,
    required this.markers,
    required this.currentPage,
    required this.totalPages,
    required this.onItemTap,
    required this.onDeleteMarker,
  });

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8E8E93).withOpacity(0.6)
                  : const Color(0xFF6E6E73).withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No bookmarks found',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF1C1C1E),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add bookmarks by tapping the bookmark icon',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF6E6E73),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Sort markers by page number
    final sortedMarkers = List<MarkerItem>.from(markers)
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: sortedMarkers.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final marker = sortedMarkers[index];
        final isCurrentPage = marker.pageNumber == currentPage;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onItemTap(marker),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: isCurrentPage
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isCurrentPage
                          ? Theme.of(context).colorScheme.primary
                          : marker.color.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.bookmark,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCurrentPage
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF2C2C2E)
                                        : const Color(0xFFF8F1F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Page ${marker.pageNumber}',
                                style: TextStyle(
                                  color: isCurrentPage
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFAA96B6)
                                          : const Color(0xFF6E6E73),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF6E6E73),
                                size: 18,
                              ),
                              onPressed: () => onDeleteMarker(marker),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          marker.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        if (marker.note != null && marker.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              marker.note!,
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
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
}

// Update the ThumbnailsView widget for a more consistent UI style
class ThumbnailsView extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final Function(int) onPageSelected;
  final Widget Function(int) getThumbnail;

  const ThumbnailsView({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.onPageSelected,
    required this.getThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading pages...',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: totalPages,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isCurrentPage = pageNumber == currentPage;

        return Material(
          elevation: isCurrentPage ? 4 : 1,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: isCurrentPage
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.5,
                    )
                  : Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      width: 1,
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isCurrentPage ? 9.5 : 11),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail
                        InkWell(
                          onTap: () => onPageSelected(pageNumber),
                          child: Hero(
                            tag: 'page_$pageNumber',
                            child: getThumbnail(pageNumber),
                          ),
                        ),

                        // Current page indicator
                        if (isCurrentPage)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.visibility,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Page number
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentPage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF8F1F1),
                    ),
                    child: Text(
                      'Page $pageNumber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isCurrentPage ? FontWeight.w600 : FontWeight.w500,
                        color: isCurrentPage
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFAA96B6)
                                : Theme.of(context).colorScheme.primary,
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
}
