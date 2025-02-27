import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/reader_loading_screen.dart';
import 'package:read_leaf/features/library/data/thumbnail_service.dart';
import 'package:get_it/get_it.dart';

class ReaderLoadingScreenRoute extends StatefulWidget {
  final String filePath;
  final String targetRoute;

  const ReaderLoadingScreenRoute({
    Key? key,
    required this.filePath,
    required this.targetRoute,
  }) : super(key: key);

  @override
  State<ReaderLoadingScreenRoute> createState() =>
      _ReaderLoadingScreenRouteState();
}

class _ReaderLoadingScreenRouteState extends State<ReaderLoadingScreenRoute> {
  double _loadingProgress = 0.0;
  bool _isCompleted = false;
  bool _isThumbnailLoaded = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _preloadThumbnail();
    _simulateLoading();
  }

  Future<void> _preloadThumbnail() async {
    try {
      final thumbnailService = GetIt.I<ThumbnailService>();
      
      // First check if thumbnail already exists
      final thumbnail = await thumbnailService.getThumbnail(widget.filePath);
      if (thumbnail != null) {
        if (mounted) {
          setState(() {
            _isThumbnailLoaded = true;
          });
        }
        return;
      }
      
      // If not, explicitly request the thumbnail to be generated
      await thumbnailService.getFileThumbnail(widget.filePath);
      if (mounted) {
        setState(() {
          _isThumbnailLoaded = true;
        });
      }
    } catch (e) {
      print('Error preloading thumbnail: $e');
      // Even if there's an error, we'll consider the thumbnail "loaded"
      // so we don't block navigation
      if (mounted) {
        setState(() {
          _isThumbnailLoaded = true;
        });
      }
    }
  }

  void _simulateLoading() {
    const totalSteps = 10;
    const baseDelay = 150; // Faster loading simulation
    
    for (int i = 1; i <= totalSteps; i++) {
      Future.delayed(Duration(milliseconds: baseDelay * i), () {
        if (mounted) {
          setState(() {
            _loadingProgress = i / totalSteps;
            
            // Mark as completed on the last step
            if (i == totalSteps) {
              _isCompleted = true;
              _navigateWhenReady();
            }
          });
        }
      });
    }
  }
  
  void _navigateWhenReady() {
    if (_isNavigating) return;
    
    // Wait for both loading to complete and thumbnail to be loaded (or timeout)
    if (_isCompleted) {
      _isNavigating = true;
      
      // If thumbnail isn't loaded yet, wait a bit longer but not too long
      if (!_isThumbnailLoaded) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, widget.targetRoute);
          }
        });
      } else {
        // If thumbnail is already loaded, add a small delay for smooth transition
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, widget.targetRoute);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReaderLoadingScreen(
      filePath: widget.filePath,
      loadingProgress: _loadingProgress,
      isCompleted: _isCompleted,
      onCompleted: () {
        // This callback is handled in _navigateWhenReady
      },
    );
  }
}
