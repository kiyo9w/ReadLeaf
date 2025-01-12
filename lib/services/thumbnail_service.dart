import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final _memoryCache = <String, ImageProvider>{};
  static const int maxMemoryCacheSize = 100;
  static const double thumbnailWidth = 150.0;
  static const double thumbnailHeight = 200.0;

  final _screenshotController = ScreenshotController();

  Future<String> _getThumbnailPath(String originalPath) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = path.basename(originalPath);
    return path.join(cacheDir.path, 'thumbnails', '${fileName}_thumb.jpg');
  }

  Future<ImageProvider> getPdfThumbnail(String filePath) async {
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
      final bytes = await _generatePdfThumbnail(filePath);
      await thumbnailFile.parent.create(recursive: true);
      await thumbnailFile.writeAsBytes(bytes);

      final provider = MemoryImage(bytes);
      _addToMemoryCache(filePath, provider);
      return provider;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return const AssetImage('assets/images/pdf_placeholder.png');
    }
  }

  Future<Uint8List> _generatePdfThumbnail(String filePath) async {
    final widget = MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(),
        child: Scaffold(
          body: SizedBox(
            width: thumbnailWidth,
            height: thumbnailHeight,
            child: PdfDocumentViewBuilder.file(
              filePath,
              builder: (context, document) {
                if (document == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return PdfPageView(
                  document: document,
                  pageNumber: 1,
                  alignment: Alignment.center,
                  maximumDpi: 150,
                  decorationBuilder: (context, pageSize, page, pageImage) {
                    return pageImage ??
                        const Center(child: CircularProgressIndicator());
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    return await _screenshotController.captureFromWidget(
      widget,
      pixelRatio: 1.0,
      targetSize: Size(thumbnailWidth, thumbnailHeight),
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
