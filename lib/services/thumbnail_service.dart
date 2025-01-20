import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';
import 'package:epubx/epubx.dart' hide Image;

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final _memoryCache = <String, ImageProvider>{};
  static const int maxMemoryCacheSize = 100;
  static const double thumbnailWidth = 150.0;
  static const double thumbnailHeight = 200.0;

  final _screenshotController = ScreenshotController();

  // Default PDF thumbnails mapping
  final Map<String, String> _defaultThumbnails = {
    'atomic_habits.pdf': 'assets/images/thumbnails/atomic_habits_thumb.jpg',
    'business_law.pdf': 'assets/images/thumbnails/business_law_thumb.jpg',
    'app_development_flutter.pdf':
        'assets/images/thumbnails/app_development_flutter_thumb.jpg',
    'gietconchimnhan.pdf': 'assets/images/thumbnails/gietconchimnhan_thumb.jpg',
  };

  Future<String> _getThumbnailPath(String originalPath) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = path.basename(originalPath);
    return path.join(cacheDir.path, 'thumbnails', '${fileName}_thumb.jpg');
  }

  Future<ImageProvider> getFileThumbnail(String filePath) async {
    final fileType = path.extension(filePath).toLowerCase();
    if (fileType == '.pdf') {
      return getPdfThumbnail(filePath);
    } else if (fileType == '.epub') {
      return getEpubThumbnail(filePath);
    }
    return const AssetImage('assets/images/pdf_placeholder.png');
  }

  Future<ImageProvider> getEpubThumbnail(String filePath) async {
    final fileName = path.basename(filePath);

    // Check memory cache first
    if (_memoryCache.containsKey(filePath)) {
      return _memoryCache[filePath]!;
    }

    // Check disk cache
    final thumbnailPath = await _getThumbnailPath(filePath);
    final thumbnailFile = File(thumbnailPath);

    if (await thumbnailFile.exists()) {
      final provider = FileImage(thumbnailFile);
      _addToMemoryCache(filePath, provider);
      return provider;
    }

    // Generate new thumbnail
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      Uint8List? coverBytes;

      // Try to get cover image
      if (book.Content?.Images?.isNotEmpty == true) {
        final possibleCoverImages = book.Content!.Images!.entries
            .where((e) => e.key.toLowerCase().contains('cover'))
            .toList();
        if (possibleCoverImages.isNotEmpty) {
          coverBytes =
              Uint8List.fromList(possibleCoverImages.first.value.Content ?? []);
        }
      }

      if (coverBytes != null && coverBytes.isNotEmpty) {
        await thumbnailFile.parent.create(recursive: true);
        await thumbnailFile.writeAsBytes(coverBytes);

        final provider = MemoryImage(coverBytes);
        _addToMemoryCache(filePath, provider);
        return provider;
      }

      // If no cover image found, generate a default one with title
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Container(
            width: thumbnailWidth * 2,
            height: thumbnailHeight * 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade200, Colors.blue.shade400],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  book.Title ?? path.basenameWithoutExtension(fileName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );

      final defaultBytes = await _screenshotController.captureFromWidget(
        widget,
        delay: const Duration(milliseconds: 200),
        pixelRatio: 2.0,
        targetSize: Size(thumbnailWidth * 2, thumbnailHeight * 2),
      );

      await thumbnailFile.parent.create(recursive: true);
      await thumbnailFile.writeAsBytes(defaultBytes);

      final provider = MemoryImage(defaultBytes);
      _addToMemoryCache(filePath, provider);
      return provider;
    } catch (e) {
      print('Error generating EPUB thumbnail: $e');
      return const AssetImage('assets/images/pdf_placeholder.png');
    }
  }

  Future<ImageProvider> getPdfThumbnail(String filePath) async {
    final fileName = path.basename(filePath);

    // Check if this is a default PDF and return its pre-cached thumbnail
    if (_defaultThumbnails.containsKey(fileName)) {
      return AssetImage(_defaultThumbnails[fileName]!);
    }

    // Check memory cache first
    if (_memoryCache.containsKey(filePath)) {
      return _memoryCache[filePath]!;
    }

    // Check disk cache
    final thumbnailPath = await _getThumbnailPath(filePath);
    final thumbnailFile = File(thumbnailPath);

    if (await thumbnailFile.exists()) {
      final provider = FileImage(thumbnailFile);
      _addToMemoryCache(filePath, provider);
      return provider;
    }

    // Generate new thumbnail
    try {
      // First load and render the PDF
      final document = await PdfDocument.openFile(filePath);
      if (document == null) {
        throw Exception('Failed to load PDF');
      }

      // Wait a bit to ensure PDF is loaded
      await Future.delayed(const Duration(milliseconds: 500));

      final bytes = await _generatePdfThumbnail(filePath, document);

      // Wait additional time to ensure proper rendering before caching
      await Future.delayed(const Duration(milliseconds: 2000));

      // Only cache if the bytes are valid
      if (bytes.isNotEmpty) {
        await thumbnailFile.parent.create(recursive: true);
        await thumbnailFile.writeAsBytes(bytes);

        final provider = MemoryImage(bytes);
        _addToMemoryCache(filePath, provider);
        return provider;
      }
      throw Exception('Generated thumbnail is empty');
    } catch (e) {
      print('Error generating thumbnail: $e');
      return const AssetImage('assets/images/pdf_placeholder.png');
    }
  }

  Future<Uint8List> _generatePdfThumbnail(
      String filePath, PdfDocument document) async {
    final widget = Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Container(
          width: thumbnailWidth * 2,
          height: thumbnailHeight * 2,
          color: Colors.white,
          child: PdfPageView(
            document: document,
            pageNumber: 1,
            alignment: Alignment.center,
            maximumDpi: 600,
            decorationBuilder: (context, pageSize, page, pageImage) {
              if (pageImage == null) return const SizedBox.shrink();
              return pageImage;
            },
          ),
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 1000));

      final bytes = await _screenshotController.captureFromWidget(
        widget,
        delay: const Duration(milliseconds: 500),
        pixelRatio: 4.0,
        targetSize: Size(thumbnailWidth * 3, thumbnailHeight * 3),
      );

      if (bytes.isEmpty) {
        throw Exception('Failed to capture thumbnail');
      }

      return bytes;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return _generateDefaultThumbnail();
    }
  }

  Future<Uint8List> _generateDefaultThumbnail() async {
    final widget = Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Container(
          width: thumbnailWidth * 2,
          height: thumbnailHeight * 2,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(
              Icons.picture_as_pdf,
              size: 100,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );

    return await _screenshotController.captureFromWidget(
      widget,
      delay: const Duration(milliseconds: 200),
      pixelRatio: 4.0,
      targetSize: Size(thumbnailWidth * 3, thumbnailHeight * 3),
    );
  }

  Future<ImageProvider> getNetworkThumbnail(String url) async {
    final file = await DefaultCacheManager().getSingleFile(url);
    final provider = FileImage(file);
    _addToMemoryCache(url, provider);
    return provider;
  }

  void _addToMemoryCache(String key, ImageProvider provider) {
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = provider;
  }

  void clearCache() {
    _memoryCache.clear();
  }
}
