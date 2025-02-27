import 'dart:async';
import 'dart:math' as math;

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:read_leaf/features/reader/data/epub_service.dart';
import 'package:read_leaf/features/reader/domain/models/epub_models.dart';
import 'package:read_leaf/features/reader/presentation/widgets/epub_viewer/epub_page_content.dart';

/// Manages loading, caching, and paginating EPUB chapters
class EpubPageManager {
  // Core data
  final EpubService _epubService = EpubService();
  EpubProcessingResult? _processingResult;
  List<EpubChapter> _flatChapters = [];
  final String _filePath;

  // Caching
  final Map<int, String> _chapterContentCache = {};
  final Map<int, List<EpubPageContent>> _chapterPagesCache = {};

  // Pagination metrics
  int _totalPages = 0;
  int _nextAbsolutePageNumber = 1;
  final Map<int, int> _wordsPerChapter = {};

  // Layout and styling
  double _fontSize = 23.0;
  double _viewportWidth = 0;
  double _viewportHeight = 0;

  // Performance tracking
  final Stopwatch _stopwatch = Stopwatch();

  // State
  bool _isDisposed = false;

  // Track the currently visible chapter in long strip mode
  int? _currentVisibleChapterIndex;

  /// Creates a new page manager for the given EPUB file
  EpubPageManager(this._filePath);

  /// Gets the total number of pages
  int get totalPages => _totalPages;

  /// Gets the flattened list of chapters
  List<EpubChapter> get chapters => _flatChapters;

  /// Gets the EPUB book
  EpubBook? get book => _processingResult?.book;

  /// Gets a flattened list of all pages across all loaded chapters
  List<EpubPageContent> get flattenedPages {
    final List<EpubPageContent> allPages = [];
    for (int i = 0; i < _flatChapters.length; i++) {
      if (_chapterPagesCache.containsKey(i)) {
        allPages.addAll(_chapterPagesCache[i]!);
      }
    }
    return allPages;
  }

  /// Initialize by loading the EPUB file
  Future<void> initialize({
    required double viewportWidth,
    required double viewportHeight,
    double fontSize = 23.0,
  }) async {
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
    _fontSize = fontSize;

    try {
      _stopwatch.reset();
      _stopwatch.start();

      // Load the EPUB through the service
      _processingResult = await _epubService.loadEpub(_filePath);
      _flatChapters = _processingResult?.chapters ?? [];

      final loadTime = _stopwatch.elapsedMilliseconds;
      print('EPUB loaded in ${loadTime}ms');

      return;
    } catch (e) {
      print('Error initializing EPUB: $e');
      rethrow;
    }
  }

  /// Load a specific chapter and its surrounding chapters
  Future<void> loadSurroundingChapters(int currentChapterIndex) async {
    if (_isDisposed) return;

    // Determine which chapters to keep loaded
    final List<int> chaptersToKeep =
        _getChapterLoadingOrder(currentChapterIndex).take(5).toList();

    // Load chapters that aren't already loaded
    for (final index in chaptersToKeep) {
      if (index >= 0 &&
          index < _flatChapters.length &&
          !_chapterPagesCache.containsKey(index)) {
        await preloadChapter(index);
        await splitChapterIntoPages(index);
      }
    }

    // Clean up chapters that aren't needed
    _cleanupCache(keepList: chaptersToKeep);

    // Calculate total pages
    _calculateTotalPages();
  }

  /// Process all chapters in background
  Future<void> processAllChaptersInBackground(
      Function(double) onProgressUpdate) async {
    if (_isDisposed) return;

    // Start with current chapter, then expand outward
    final orderedChapters = List<int>.generate(_flatChapters.length, (i) => i);

    // Process in chunks to avoid blocking UI
    int processedCount = 0;
    const chunkSize = 3; // Process 3 chapters at a time

    while (processedCount < orderedChapters.length && !_isDisposed) {
      final chunk = orderedChapters.skip(processedCount).take(chunkSize);

      for (final chapterIndex in chunk) {
        if (_isDisposed) return;
        await preloadChapter(chapterIndex);
        await splitChapterIntoPages(chapterIndex);
      }

      processedCount += chunkSize;
      _calculateTotalPages();

      // Report progress
      final progress = processedCount / orderedChapters.length;
      onProgressUpdate(progress);

      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Load remaining chapters in background after showing initial content
  Future<void> loadRemainingChaptersInBackground() async {
    if (_isDisposed) return;

    // Get chapters that aren't loaded yet
    final loadedChapters = _chapterPagesCache.keys.toSet();
    final chaptersToLoad = List<int>.generate(_flatChapters.length, (i) => i)
        .where((i) => !loadedChapters.contains(i))
        .toList();

    if (chaptersToLoad.isEmpty) return;

    // Process in smaller chunks
    int processedCount = 0;
    const chunkSize = 2;

    while (processedCount < chaptersToLoad.length && !_isDisposed) {
      final chunk = chaptersToLoad.skip(processedCount).take(chunkSize);

      for (final chapterIndex in chunk) {
        if (_isDisposed) return;
        await preloadChapter(chapterIndex);
        await splitChapterIntoPages(chapterIndex);
      }

      processedCount += chunkSize;
      _calculateTotalPages();

      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Preload a specific chapter's content
  Future<void> preloadChapter(int chapterIndex) async {
    if (_isDisposed) return;
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;

    // Check if already cached
    if (_chapterContentCache.containsKey(chapterIndex)) {
      return;
    }

    try {
      _stopwatch.reset();
      _stopwatch.start();

      // Get chapter content from the service
      final content = await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: chapterIndex,
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
        fontSize: _fontSize,
      );

      // Extract the HTML content from the first page or create an empty string
      final htmlContent = content.isNotEmpty
          ? content.first.content
          : '<p>Empty chapter content</p>';

      // Cache the content
      _chapterContentCache[chapterIndex] = htmlContent;

      // Count words for reading stats
      final wordCount =
          htmlContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      _wordsPerChapter[chapterIndex] = wordCount;

      print(
          'Chapter $chapterIndex loaded in ${_stopwatch.elapsedMilliseconds}ms (${wordCount} words)');
    } catch (e) {
      print('Error loading chapter $chapterIndex: $e');
      // Cache empty content to avoid repeated failures
      _chapterContentCache[chapterIndex] = '<p>Error loading chapter: $e</p>';
      _wordsPerChapter[chapterIndex] = 0;
    }
  }

  /// Split a chapter into pages
  Future<void> splitChapterIntoPages(int chapterIndex) async {
    if (_isDisposed) return;
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) return;

    // Skip if already cached
    if (_chapterPagesCache.containsKey(chapterIndex)) {
      return;
    }

    try {
      _stopwatch.reset();
      _stopwatch.start();

      // Get content (load if not already loaded)
      if (!_chapterContentCache.containsKey(chapterIndex)) {
        await preloadChapter(chapterIndex);
      }

      final content = _chapterContentCache[chapterIndex]!;
      final chapter = _flatChapters[chapterIndex];

      // Calculate pages using the service
      final pages = await _epubService.calculatePages(
        processingResult: _processingResult!,
        chapterIndex: chapterIndex,
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
        fontSize: _fontSize,
      );

      // Convert to our model and set absolute page numbers
      final result = pages.map((page) {
        return EpubPageContent(
          content: page.content,
          chapterIndex: page.chapterIndex,
          pageNumberInChapter: page.pageNumberInChapter,
          chapterTitle: page.chapterTitle,
          wordCount: _wordsPerChapter[chapterIndex] ?? 0,
          absolutePageNumber: _nextAbsolutePageNumber++,
        );
      }).toList();

      // Cache the result
      _chapterPagesCache[chapterIndex] = result;

      print(
          'Chapter $chapterIndex paginated in ${_stopwatch.elapsedMilliseconds}ms (${result.length} pages)');
    } catch (e) {
      print('Error paginating chapter $chapterIndex: $e');
      // Create a single error page
      _chapterPagesCache[chapterIndex] = [
        EpubPageContent(
          content: '<p>Error paginating chapter: $e</p>',
          chapterIndex: chapterIndex,
          pageNumberInChapter: 1,
          chapterTitle: _flatChapters[chapterIndex].Title ??
              'Chapter ${chapterIndex + 1}',
          wordCount: 0,
          absolutePageNumber: _nextAbsolutePageNumber++,
        )
      ];
    }
  }

  /// Update the font size and recalculate pages
  Future<void> updateFontSize(double newFontSize) async {
    if (_fontSize == newFontSize) return;

    _fontSize = newFontSize;

    // Clear cached pages since they need recalculation
    _chapterPagesCache.clear();
    _nextAbsolutePageNumber = 1;

    // Reload current chapters
    for (final chapterIndex in _chapterContentCache.keys.toList()) {
      await splitChapterIntoPages(chapterIndex);
    }

    _calculateTotalPages();
  }

  /// Calculate total pages across all chapters
  void _calculateTotalPages() {
    _stopwatch.reset();
    _stopwatch.start();

    int total = 0;

    // Sum pages across all chapters
    for (final pages in _chapterPagesCache.values) {
      total += pages.length;
    }

    _totalPages = total;

    // Log performance if it took a significant amount of time
    if (_stopwatch.elapsedMilliseconds > 10) {
      print(
          'Calculated total pages in ${_stopwatch.elapsedMilliseconds}ms: $_totalPages pages');
    }
  }

  /// Clean up the cache by removing chapters not in the keep list
  void _cleanupCache({List<int>? keepList}) {
    if (keepList == null || keepList.isEmpty) return;

    _stopwatch.reset();
    _stopwatch.start();

    // Determine which chapters to remove
    final chaptersToRemove = _chapterContentCache.keys
        .where((index) => !keepList.contains(index))
        .toList();

    // Remove from caches
    for (final index in chaptersToRemove) {
      _chapterContentCache.remove(index);
      _chapterPagesCache.remove(index);
    }

    if (chaptersToRemove.isNotEmpty) {
      print(
          'Cleaned up ${chaptersToRemove.length} chapters from cache in ${_stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Get chapters in loading priority order (starting from current, then outward)
  List<int> _getChapterLoadingOrder(int currentIndex) {
    final result = <int>[];

    // Start with current chapter
    result.add(currentIndex);

    // Add chapters in expanding radius (next, previous, next+1, previous+1, etc.)
    int radius = 1;
    while (result.length < _flatChapters.length) {
      final nextIndex = currentIndex + radius;
      final prevIndex = currentIndex - radius;

      if (nextIndex < _flatChapters.length) {
        result.add(nextIndex);
      }

      if (prevIndex >= 0) {
        result.add(prevIndex);
      }

      radius++;

      // Stop if we've covered all chapters
      if (prevIndex < 0 && nextIndex >= _flatChapters.length) {
        break;
      }
    }

    // Filter to valid indices only
    return result.where((i) => i >= 0 && i < _flatChapters.length).toList();
  }

  /// Get a page by its absolute number
  EpubPageContent? getPageByAbsoluteNumber(int absoluteNumber) {
    // Look through all loaded chapters
    for (final pages in _chapterPagesCache.values) {
      for (final page in pages) {
        if (page.absolutePageNumber == absoluteNumber) {
          return page;
        }
      }
    }
    return null;
  }

  /// Get a chapter's pages (loading if necessary)
  Future<List<EpubPageContent>> getChapterPages(int chapterIndex) async {
    if (chapterIndex < 0 || chapterIndex >= _flatChapters.length) {
      return [];
    }

    // Load if not already loaded
    if (!_chapterPagesCache.containsKey(chapterIndex)) {
      await preloadChapter(chapterIndex);
      await splitChapterIntoPages(chapterIndex);
    }

    return _chapterPagesCache[chapterIndex] ?? [];
  }

  /// Find the chapter and page for a given absolute page number
  Future<(int, int)> findChapterAndPageByAbsoluteNumber(
      int absoluteNumber) async {
    // First look in already loaded chapters
    for (final entry in _chapterPagesCache.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].absolutePageNumber == absoluteNumber) {
          return (entry.key, i);
        }
      }
    }

    // If not found, we need to load more chapters
    for (int i = 0; i < _flatChapters.length; i++) {
      if (!_chapterPagesCache.containsKey(i)) {
        final pages = await getChapterPages(i);
        for (int j = 0; j < pages.length; j++) {
          if (pages[j].absolutePageNumber == absoluteNumber) {
            return (i, j);
          }
        }
      }
    }

    // If still not found, return the first chapter/page
    return (0, 0);
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _chapterContentCache.clear();
    _chapterPagesCache.clear();
    _wordsPerChapter.clear();
  }

  /// Get the current progress as a value between 0.0 and 1.0 when in long strip mode
  /// This can be used to restore position when switching to paginated mode
  double getCurrentLongStripProgress() {
    // Get the scroll position from the scroll controller if available
    // This is a placeholder - in a real implementation, you would need to:
    // 1. Store a reference to the scroll controller used in long strip mode
    // 2. Calculate progress based on scroll position divided by total content height

    // For now, we'll estimate based on the current chapter and our best guess
    if (_processingResult == null) return 0.0;

    int totalChapters = _flatChapters.length;
    if (totalChapters == 0) return 0.0;

    // If we know the current chapter index, use it to estimate progress
    int currentChapterIndex = _currentVisibleChapterIndex ?? 0;

    // Calculate progress based on chapter position
    return math.min(1.0, currentChapterIndex / totalChapters);
  }

  /// Convert a progress value (0.0 to 1.0) to a page number in paginated mode
  int getPageNumberFromProgress(double progress) {
    if (_totalPages == 0) return 1;

    // Calculate target page based on progress
    final targetPage = (progress * _totalPages).round();

    // Ensure page is within valid range
    return math.max(1, math.min(_totalPages, targetPage));
  }

  /// Update the currently visible chapter in long strip mode
  void updateVisibleChapterInLongStrip(int chapterIndex) {
    _currentVisibleChapterIndex = chapterIndex;
  }
}
