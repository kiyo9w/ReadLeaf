import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:read_leaf/features/library/domain/models/book_metadata.dart';
import 'package:read_leaf/features/reader/presentation/controllers/epub_layout_controller.dart';
import 'package:read_leaf/features/reader/presentation/managers/epub_highlight_manager.dart';
import 'package:read_leaf/features/reader/presentation/managers/epub_page_manager.dart';

/// Manages the overall state of the EPUB reader
class EpubStateManager extends ChangeNotifier {
  // Core data managers
  final EpubPageManager _pageManager;
  final EpubHighlightManager _highlightManager;
  final EpubLayoutController _layoutController;
  final BookMetadataRepository _metadataRepository;

  // Book info
  final File _file;
  BookMetadata? _metadata;
  ImageProvider? _coverImage;

  // Reading state
  int _currentPage = 1;
  int _currentChapterIndex = 0;
  String? _selectedText;
  bool _isLoading = true;
  bool _showChapters = false;

  // UI flags
  final bool _showAskAiButton = false;
  bool _isDisposed = false;
  bool _isSliderInteracting = false;
  Timer? _sliderDwellTimer;

  /// Creates a new state manager for the given EPUB file
  EpubStateManager({
    required File file,
    required BookMetadataRepository metadataRepository,
    required EpubPageManager pageManager,
    required EpubHighlightManager highlightManager,
    required EpubLayoutController layoutController,
  })  : _file = file,
        _metadataRepository = metadataRepository,
        _pageManager = pageManager,
        _highlightManager = highlightManager,
        _layoutController = layoutController;

  /// Gets the EPUB page manager
  EpubPageManager get pageManager => _pageManager;

  /// Gets the highlight manager
  EpubHighlightManager get highlightManager => _highlightManager;

  /// Gets the layout controller
  EpubLayoutController get layoutController => _layoutController;

  /// Gets the book file
  File get file => _file;

  /// Gets the book's metadata
  BookMetadata? get metadata => _metadata;

  /// Gets the book cover image
  ImageProvider? get coverImage => _coverImage;

  /// Gets the current page number
  int get currentPage => _currentPage;

  /// Gets the current chapter index
  int get currentChapterIndex => _currentChapterIndex;

  /// Gets the currently selected text
  String? get selectedText => _selectedText;

  /// Gets whether the reader is loading
  bool get isLoading => _isLoading;

  /// Gets whether to show the chapters panel
  bool get showChapters => _showChapters;

  /// Gets the total number of pages
  int get totalPages => _pageManager.totalPages;

  /// Gets whether to show the AI button
  bool get showAskAiButton => _showAskAiButton;

  /// Gets the EPUB book
  EpubBook? get book => _pageManager.book;

  /// Gets the flattened list of chapters
  List<EpubChapter> get chapters => _pageManager.chapters;

  /// Gets the slider value for progress bar
  double get sliderValue =>
      _currentPage.clamp(1, math.max(1, totalPages)).toDouble();

  /// Gets the maximum slider value
  double get sliderMax => math.max(1.0, totalPages.toDouble());

  /// Initialize the reader
  Future<void> initialize({
    required double viewportWidth,
    required double viewportHeight,
  }) async {
    _setLoading(true);

    try {
      // Initialize page manager
      await _pageManager.initialize(
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
        fontSize: _layoutController.fontSize,
      );

      // Load metadata
      await _loadMetadata();

      // Load initial content based on layout mode
      if (_layoutController.layoutMode == EpubLayoutMode.vertical ||
          _layoutController.layoutMode == EpubLayoutMode.longStrip) {
        // For these modes, load chapters in background
        _pageManager.processAllChaptersInBackground((progress) {
          // Could update a progress indicator here
        });
      } else {
        // Only load current chapter and surrounding ones for other layouts
        await _pageManager.loadSurroundingChapters(_currentChapterIndex);
      }

      // Now we're ready to show content
      _setLoading(false);

      // Continue loading remaining chapters in background
      if (_layoutController.layoutMode != EpubLayoutMode.vertical &&
          _layoutController.layoutMode != EpubLayoutMode.longStrip) {
        _pageManager.loadRemainingChaptersInBackground();
      }

      // Update metadata with correct total pages after pagination
      await _updateMetadataWithCurrentProgress();
    } catch (e) {
      debugPrint('Error initializing EPUB reader: $e');
      _setLoading(false);
      rethrow;
    }
  }

  /// Load the book's metadata
  Future<void> _loadMetadata() async {
    final metadata = _metadataRepository.getMetadata(_file.path);

    if (metadata != null) {
      _metadata = metadata;
      if (metadata.lastOpenedPage > 0) {
        _currentPage = metadata.lastOpenedPage;
      }
    } else {
      // Create new metadata if none exists
      final bookTitle = book?.Title ?? path.basename(_file.path);
      final bookAuthor = book?.Author ?? 'Unknown';

      final newMetadata = BookMetadata(
        filePath: _file.path,
        title: bookTitle,
        author: bookAuthor,
        lastOpenedPage: 1,
        totalPages: 0, // Will be updated later
        readingProgress: 0.0,
        lastReadTime: DateTime.now(),
        fileType: 'epub',
        highlights: [],
        aiConversations: [],
        isStarred: false,
      );

      await _metadataRepository.saveMetadata(newMetadata);
      _metadata = newMetadata;
    }

    // Load highlights if they exist
    if (_metadata?.highlights != null && _metadata!.highlights.isNotEmpty) {
      final highlightMaps = _metadata!.highlights
          .map((highlight) => {
                'text': highlight.text,
                'chapterIndex': highlight.pageNumber - 1,
                'pageNumberInChapter': 0, // Default value
                'color': Colors.yellow.value,
                'createdAt': highlight.createdAt.millisecondsSinceEpoch,
                'note': highlight.note,
              })
          .toList();

      _highlightManager.loadFromList(highlightMaps);
    }

    notifyListeners();
  }

  /// Update the book's metadata with current progress
  Future<void> _updateMetadataWithCurrentProgress() async {
    if (_metadata == null || _isDisposed) return;

    // Ensure currentPage doesn't exceed total pages
    final validatedPage = _currentPage.clamp(1, totalPages);

    // Calculate progress as a percentage between 0.0 and 1.0
    final progress =
        totalPages > 0 ? (validatedPage / totalPages).clamp(0.0, 1.0) : 0.0;

    // Get current highlights
    final currentHighlights = _highlightManager.exportToList();

    // Convert highlights to TextHighlight objects
    final convertedHighlights = currentHighlights
        .map((map) => TextHighlight(
              text: map['text'] as String,
              pageNumber: (map['chapterIndex'] as int) + 1,
              note: map['note'] as String?,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
            ))
        .toList();

    // Update metadata with current page and progress
    final updatedMetadata = _metadata!.copyWith(
      lastOpenedPage: validatedPage,
      lastReadTime: DateTime.now(),
      readingProgress: progress,
      totalPages: totalPages, // Ensure total pages is always up to date
      highlights: convertedHighlights,
    );

    await _metadataRepository.saveMetadata(updatedMetadata);
    _metadata = updatedMetadata;

    notifyListeners();
  }

  /// Set the loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set the current page
  void setCurrentPage(int page) {
    if (_currentPage != page) {
      _currentPage = page;
      _updateMetadataWithCurrentProgress();
      notifyListeners();
    }
  }

  /// Set the current chapter
  void setCurrentChapter(int chapterIndex) {
    if (_currentChapterIndex != chapterIndex &&
        chapterIndex >= 0 &&
        chapterIndex < chapters.length) {
      _currentChapterIndex = chapterIndex;
      _pageManager.loadSurroundingChapters(chapterIndex);
      notifyListeners();
    }
  }

  /// Toggle showing the chapters panel
  void toggleChaptersPanel() {
    _showChapters = !_showChapters;
    notifyListeners();
  }

  /// Set selected text
  void setSelectedText(String? text) {
    _selectedText = text;
    notifyListeners();
  }

  /// Handle slider interaction start
  void onSliderInteractionStart() {
    _isSliderInteracting = true;
  }

  /// Handle slider value change
  void onSliderValueChanged(double value) {
    // Cancel any existing timer
    _sliderDwellTimer?.cancel();

    // Schedule navigation after a short delay
    _sliderDwellTimer = Timer(const Duration(milliseconds: 200), () {
      final targetPage = value.round();
      navigateToPage(targetPage);
    });
  }

  /// Handle slider interaction end
  void onSliderInteractionEnd(double value) {
    // Cancel any existing timer
    _sliderDwellTimer?.cancel();

    // Navigate immediately
    final targetPage = value.round();
    navigateToPage(targetPage);

    _isSliderInteracting = false;
  }

  /// Navigate to a specific page
  Future<void> navigateToPage(int page) async {
    if (page < 1 || page > totalPages || page == _currentPage) return;

    setCurrentPage(page);

    // Find the chapter for this page
    final pageContent = _pageManager.getPageByAbsoluteNumber(page);
    if (pageContent != null) {
      setCurrentChapter(pageContent.chapterIndex);

      // Use layout controller to handle actual navigation
      _layoutController.jumpToPage(page);
    } else {
      // If page is not loaded yet, find its chapter
      final (chapterIndex, pageInChapter) =
          await _pageManager.findChapterAndPageByAbsoluteNumber(page);
      setCurrentChapter(chapterIndex);

      // Use layout controller after a short delay to allow chapter loading
      await Future.delayed(const Duration(milliseconds: 100));
      _layoutController.jumpToPage(page);
    }
  }

  /// Change the layout mode
  void changeLayoutMode(EpubLayoutMode newMode) {
    // Store current mode before changing
    final previousMode = _layoutController.layoutMode;

    // Remember current progress before switching
    double currentProgress = 0.0;
    if (previousMode == EpubLayoutMode.longStrip &&
        (newMode == EpubLayoutMode.vertical ||
            newMode == EpubLayoutMode.horizontal)) {
      // When switching from long strip to paginated mode, we need to save position
      currentProgress = _pageManager.getCurrentLongStripProgress();
    }

    // Change layout mode in controller
    _layoutController.changeLayoutMode(newMode);

    // Load chapters appropriate for the new layout mode
    if (newMode == EpubLayoutMode.vertical ||
        newMode == EpubLayoutMode.longStrip) {
      _pageManager.processAllChaptersInBackground((progress) {});
    } else {
      _pageManager.loadSurroundingChapters(_currentChapterIndex);
      _pageManager.loadRemainingChaptersInBackground();
    }

    // If switching from long strip to paginated mode, restore position
    if (previousMode == EpubLayoutMode.longStrip &&
        (newMode == EpubLayoutMode.vertical ||
            newMode == EpubLayoutMode.horizontal)) {
      // Delay to allow pages to calculate
      Future.delayed(const Duration(milliseconds: 300), () {
        final targetPage =
            _pageManager.getPageNumberFromProgress(currentProgress);
        if (targetPage > 0) {
          navigateToPage(targetPage);
        }
      });
    }
  }

  /// Update the font size
  Future<void> updateFontSize(double newSize) async {
    // Update controller first
    _layoutController.changeFontSize(newSize);

    // Then recalculate pages with new font size
    _setLoading(true);
    await _pageManager.updateFontSize(newSize);
    _setLoading(false);

    // Update metadata
    await _updateMetadataWithCurrentProgress();
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _updateMetadataWithCurrentProgress();
      _pageManager.dispose();
      _highlightManager.dispose();
      _layoutController.dispose();
      _sliderDwellTimer?.cancel();
      _isDisposed = true;
    }
    super.dispose();
  }
}
