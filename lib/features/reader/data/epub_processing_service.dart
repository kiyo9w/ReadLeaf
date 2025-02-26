// import 'dart:io';
// import 'dart:async';
// import 'package:epubx/epubx.dart';
// import 'package:flutter/foundation.dart';
// import 'package:path/path.dart' as path;
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import '../utils/epub_isolate_utils.dart';
// import '../models/epub_page_content.dart';

// /// A service that handles optimized EPUB loading and processing
// class EpubProcessingService {
//   // Cache for paginated content by filepath and font size
//   final Map<String, Map<double, EpubPaginationMetrics>> _paginationCache = {};
//   final Map<String, Map<int, List<EpubPageContent>>> _pageContentCache = {};

//   // Persistent storage key for saving/loading pagination metrics
//   static const String _paginationCacheKey = 'epub_pagination_cache';
//   static const int _maxCachedBooks = 10;

//   // Lifecycle management
//   bool _isDisposed = false;

//   // Initialize and load any cached pagination data
//   Future<void> initialize() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final cachedData = prefs.getString(_paginationCacheKey);

//       if (cachedData != null) {
//         final Map<String, dynamic> cacheMap = jsonDecode(cachedData);

//         // Load cached pagination metrics
//         for (final filepath in cacheMap.keys) {
//           _paginationCache[filepath] = {};
//           final Map<String, dynamic> fontSizeMap = cacheMap[filepath];

//           for (final fontSizeStr in fontSizeMap.keys) {
//             final double fontSize = double.parse(fontSizeStr);
//             final Map<String, dynamic> metricsMap = fontSizeMap[fontSizeStr];
//             _paginationCache[filepath]![fontSize] =
//                 EpubPaginationMetrics.fromMap(metricsMap);
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('Error loading cached pagination data: $e');
//       // Continue without cached data
//     }
//   }

//   // Save pagination metrics to persistent storage
//   Future<void> _savePaginationCache() async {
//     if (_isDisposed) return;

//     try {
//       final prefs = await SharedPreferences.getInstance();

//       // Convert to serializable format
//       final Map<String, Map<String, dynamic>> serializedCache = {};

//       for (final filepath in _paginationCache.keys) {
//         serializedCache[filepath] = {};
//         final fontSizeMap = _paginationCache[filepath]!;

//         for (final fontSize in fontSizeMap.keys) {
//           serializedCache[filepath]![fontSize.toString()] =
//               fontSizeMap[fontSize]!.toMap();
//         }
//       }

//       // Prune older items if we exceed the max cache size
//       if (serializedCache.length > _maxCachedBooks) {
//         final entries = serializedCache.entries.toList()
//           ..sort((a, b) {
//             final aTime = EpubPaginationMetrics.fromMap(
//                     (a.value.values.first as Map<String, dynamic>))
//                 .calculatedAt;
//             final bTime = EpubPaginationMetrics.fromMap(
//                     (b.value.values.first as Map<String, dynamic>))
//                 .calculatedAt;
//             return aTime.compareTo(bTime); // Sort oldest first
//           });

//         // Keep only the newest items
//         serializedCache.clear();
//         for (int i = entries.length - _maxCachedBooks;
//             i < entries.length;
//             i++) {
//           final entry = entries[i];
//           serializedCache[entry.key] = entry.value;
//         }
//       }

//       final jsonString = jsonEncode(serializedCache);
//       await prefs.setString(_paginationCacheKey, jsonString);
//     } catch (e) {
//       debugPrint('Error saving pagination cache: $e');
//     }
//   }

//   // Load an EPUB file (lightweight initial load)
//   Future<EpubBook?> loadEpubFile(String filepath) async {
//     try {
//       final File file = File(filepath);
//       if (!await file.exists()) {
//         throw Exception('File does not exist: $filepath');
//       }

//       final bytes = await file.readAsBytes();
//       return await EpubReader.readBook(bytes);
//     } catch (e) {
//       debugPrint('Error loading EPUB file: $e');
//       return null;
//     }
//   }

//   // Get pagination metrics for a book, either from cache or by calculating
//   Future<EpubPaginationMetrics> getPaginationMetrics({
//     required String filepath,
//     required List<EpubChapter> chapters,
//     required double fontSize,
//     required double viewportWidth,
//     required double viewportHeight,
//     bool forceRecalculate = false,
//   }) async {
//     // Check if we have cached metrics that match the current settings
//     if (!forceRecalculate &&
//         _paginationCache.containsKey(filepath) &&
//         _paginationCache[filepath]!.containsKey(fontSize)) {
//       final metrics = _paginationCache[filepath]![fontSize]!;
//       if (metrics.matchesSettings(
//           fontSize: fontSize,
//           viewportWidth: viewportWidth,
//           viewportHeight: viewportHeight)) {
//         return metrics;
//       }
//     }

//     // Need to calculate pagination metrics
//     try {
//       final stopwatch = Stopwatch()..start();

//       final List<ChapterProcessingData> chaptersToProcess = [];

//       // Prepare chapter data for processing
//       for (int i = 0; i < chapters.length; i++) {
//         final chapter = chapters[i];
//         if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
//           continue;
//         }

//         chaptersToProcess.add(ChapterProcessingData(
//           htmlContent: chapter.HtmlContent!,
//           chapterIndex: i,
//           chapterTitle: chapter.Title ?? 'Chapter ${i + 1}',
//           fontSize: fontSize,
//           viewportWidth: viewportWidth,
//           viewportHeight: viewportHeight,
//         ));
//       }

//       // Process chapters in parallel
//       final processor = ParallelChapterProcessor(
//         maxConcurrentProcessing: 2, // Adjust based on device capabilities
//       );

//       final results = await processor.processChapters(chaptersToProcess);

//       // Calculate total pages and words
//       int totalPages = 0;
//       int totalWords = 0;
//       final List<ChapterPaginationInfo> chapterInfo = [];

//       for (final result in results) {
//         if (!result.success) {
//           debugPrint(
//               'Error processing chapter ${result.chapterIndex}: ${result.error}');
//           continue;
//         }

//         final startPage = totalPages + 1;
//         final pageCount = result.pages.length;
//         totalPages += pageCount;
//         totalWords += result.wordCount;

//         chapterInfo.add(ChapterPaginationInfo(
//           chapterIndex: result.chapterIndex,
//           chapterTitle: chapters[result.chapterIndex].Title ??
//               'Chapter ${result.chapterIndex + 1}',
//           pageCount: pageCount,
//           wordCount: result.wordCount,
//           startAbsolutePageNumber: startPage,
//           endAbsolutePageNumber: startPage + pageCount - 1,
//         ));

//         // Cache the pages
//         if (!_pageContentCache.containsKey(filepath)) {
//           _pageContentCache[filepath] = {};
//         }

//         final List<EpubPageContent> pageContents = [];
//         for (int i = 0; i < result.pages.length; i++) {
//           final pageMap = result.pages[i];
//           pageContents.add(EpubPageContent.fromMap({
//             ...pageMap,
//             'absolutePageNumber': startPage + i,
//             'wordCount': 0, // We don't track per-page word count yet
//           }));
//         }

//         _pageContentCache[filepath]![result.chapterIndex] = pageContents;
//       }

//       // Create and cache the pagination metrics
//       final metrics = EpubPaginationMetrics(
//         totalPages: totalPages,
//         totalWords: totalWords,
//         fontSize: fontSize,
//         viewportWidth: viewportWidth,
//         viewportHeight: viewportHeight,
//         chapterInfo: chapterInfo,
//         calculatedAt: DateTime.now(),
//       );

//       if (!_paginationCache.containsKey(filepath)) {
//         _paginationCache[filepath] = {};
//       }
//       _paginationCache[filepath]![fontSize] = metrics;

//       // Save to persistent storage
//       unawaited(_savePaginationCache());

//       stopwatch.stop();
//       debugPrint('Pagination calculated in ${stopwatch.elapsedMilliseconds}ms');

//       return metrics;
//     } catch (e) {
//       debugPrint('Error calculating pagination: $e');
//       return EpubPaginationMetrics.empty();
//     }
//   }

//   // Get pages for a specific chapter
//   Future<List<EpubPageContent>> getPagesForChapter({
//     required String filepath,
//     required EpubBook book,
//     required int chapterIndex,
//     required double fontSize,
//     required double viewportWidth,
//     required double viewportHeight,
//     bool forceReload = false,
//   }) async {
//     try {
//       // Check if we have this chapter cached
//       if (!forceReload &&
//           _pageContentCache.containsKey(filepath) &&
//           _pageContentCache[filepath]!.containsKey(chapterIndex)) {
//         return _pageContentCache[filepath]![chapterIndex]!;
//       }

//       // We don't have it cached, process the chapter
//       final flatChapters = _flattenChapters(book.Chapters ?? []);
//       if (chapterIndex < 0 || chapterIndex >= flatChapters.length) {
//         throw Exception('Invalid chapter index: $chapterIndex');
//       }

//       final chapter = flatChapters[chapterIndex];
//       if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
//         throw Exception('Chapter has no content');
//       }

//       // Process the chapter
//       final data = ChapterProcessingData(
//         htmlContent: chapter.HtmlContent!,
//         chapterIndex: chapterIndex,
//         chapterTitle: chapter.Title ?? 'Chapter ${chapterIndex + 1}',
//         fontSize: fontSize,
//         viewportWidth: viewportWidth,
//         viewportHeight: viewportHeight,
//       );

//       final result = await EpubIsolateManager.processChapter(data);

//       if (!result.success) {
//         throw Exception('Error processing chapter: ${result.error}');
//       }

//       // Check if we have pagination metrics for this book
//       EpubPaginationMetrics? metrics;
//       if (_paginationCache.containsKey(filepath) &&
//           _paginationCache[filepath]!.containsKey(fontSize)) {
//         metrics = _paginationCache[filepath]![fontSize];
//       }

//       // Get the starting absolute page for this chapter
//       int startAbsolutePage = 1;
//       if (metrics != null) {
//         final chapterInfoOpt = metrics.chapterInfo
//             .where((info) => info.chapterIndex == chapterIndex)
//             .toList();

//         if (chapterInfoOpt.isNotEmpty) {
//           startAbsolutePage = chapterInfoOpt.first.startAbsolutePageNumber;
//         }
//       }

//       // Create and cache page contents
//       final List<EpubPageContent> pageContents = [];
//       for (int i = 0; i < result.pages.length; i++) {
//         final pageMap = result.pages[i];
//         pageContents.add(EpubPageContent.fromMap({
//           ...pageMap,
//           'absolutePageNumber': startAbsolutePage + i,
//           'wordCount': 0, // We don't track per-page word count yet
//         }));
//       }

//       if (!_pageContentCache.containsKey(filepath)) {
//         _pageContentCache[filepath] = {};
//       }
//       _pageContentCache[filepath]![chapterIndex] = pageContents;

//       return pageContents;
//     } catch (e) {
//       debugPrint('Error getting pages for chapter: $e');
//       return [];
//     }
//   }

//   // Get a specific page by absolute page number
//   Future<EpubPageContent?> getPageByNumber({
//     required String filepath,
//     required EpubBook book,
//     required int absolutePageNumber,
//     required double fontSize,
//     required double viewportWidth,
//     required double viewportHeight,
//     bool forceReload = false,
//   }) async {
//     try {
//       // Check if we have metrics for this book
//       if (!_paginationCache.containsKey(filepath) ||
//           !_paginationCache[filepath]!.containsKey(fontSize)) {
//         // Get pagination metrics first
//         final flatChapters = _flattenChapters(book.Chapters ?? []);
//         await getPaginationMetrics(
//           filepath: filepath,
//           chapters: flatChapters,
//           fontSize: fontSize,
//           viewportWidth: viewportWidth,
//           viewportHeight: viewportHeight,
//         );
//       }

//       // Now find the chapter that contains this page
//       final metrics = _paginationCache[filepath]![fontSize]!;

//       // Find the chapter containing this page
//       ChapterPaginationInfo? targetChapter;
//       for (final chapter in metrics.chapterInfo) {
//         if (absolutePageNumber >= chapter.startAbsolutePageNumber &&
//             absolutePageNumber <= chapter.endAbsolutePageNumber) {
//           targetChapter = chapter;
//           break;
//         }
//       }

//       if (targetChapter == null) {
//         throw Exception('Page number out of range: $absolutePageNumber');
//       }

//       // Get the pages for this chapter
//       final pages = await getPagesForChapter(
//         filepath: filepath,
//         book: book,
//         chapterIndex: targetChapter.chapterIndex,
//         fontSize: fontSize,
//         viewportWidth: viewportWidth,
//         viewportHeight: viewportHeight,
//         forceReload: forceReload,
//       );

//       // Find the specific page
//       final pageIndexInChapter =
//           absolutePageNumber - targetChapter.startAbsolutePageNumber;
//       if (pageIndexInChapter < 0 || pageIndexInChapter >= pages.length) {
//         throw Exception('Page index out of range');
//       }

//       return pages[pageIndexInChapter];
//     } catch (e) {
//       debugPrint('Error getting page by number: $e');
//       return null;
//     }
//   }

//   // Helper method to flatten chapters
//   List<EpubChapter> _flattenChapters(List<EpubChapter> chapters,
//       [int level = 0]) {
//     List<EpubChapter> result = [];
//     for (var chapter in chapters) {
//       result.add(chapter);
//       if (chapter.SubChapters?.isNotEmpty == true) {
//         result.addAll(_flattenChapters(chapter.SubChapters!, level + 1));
//       }
//     }
//     return result;
//   }

//   // Clear all caches
//   void clearCache() {
//     _paginationCache.clear();
//     _pageContentCache.clear();
//     EpubIsolateManager.killAll();
//     _savePaginationCache();
//   }

//   // Clear cache for a specific book
//   void clearBookCache(String filepath) {
//     _paginationCache.remove(filepath);
//     _pageContentCache.remove(filepath);
//     _savePaginationCache();
//   }

//   // Dispose resources
//   void dispose() {
//     _isDisposed = true;
//     EpubIsolateManager.killAll();
//   }
// }
