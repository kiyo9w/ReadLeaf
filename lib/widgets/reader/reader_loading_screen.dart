import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:read_leaf/services/thumbnail_service.dart';
import 'package:get_it/get_it.dart';

class ReaderLoadingScreen extends StatefulWidget {
  final String filePath;
  final double loadingProgress;
  final bool isCompleted;
  final VoidCallback? onCompleted;

  const ReaderLoadingScreen({
    Key? key,
    required this.filePath,
    this.loadingProgress = 0.0,
    this.isCompleted = false,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<ReaderLoadingScreen> createState() => _ReaderLoadingScreenState();
}

class _ReaderLoadingScreenState extends State<ReaderLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;

  ImageProvider? _thumbnailImage;
  bool _hasLoadedThumbnail = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _blurAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _loadThumbnail();
    _animationController.forward();

    // If already completed when widget is created, trigger the onCompleted callback
    if (widget.isCompleted && widget.onCompleted != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        widget.onCompleted!();
      });
    }
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbnailService = GetIt.I<ThumbnailService>();
      final fileExtension = path.extension(widget.filePath).toLowerCase();

      if (fileExtension == '.pdf' || fileExtension == '.epub') {
        final file = File(widget.filePath);
        if (await file.exists()) {
          // First try to get a cached thumbnail
          final thumbnail =
              await thumbnailService.getThumbnail(widget.filePath);
          if (mounted && thumbnail != null) {
            setState(() {
              _thumbnailImage = FileImage(thumbnail);
              _hasLoadedThumbnail = true;
            });
            return;
          }

          // If no cached thumbnail, try to generate one
          final imageProvider =
              await thumbnailService.getFileThumbnail(widget.filePath);
          if (mounted) {
            setState(() {
              _thumbnailImage = imageProvider;
              _hasLoadedThumbnail = true;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
      // Show a default thumbnail if there's an error
      if (mounted) {
        final fileExtension = path.extension(widget.filePath).toLowerCase();
        setState(() {
          _thumbnailImage = AssetImage(fileExtension == '.pdf'
              ? 'assets/images/pdf_placeholder.png'
              : 'assets/images/epub_placeholder.png');
          _hasLoadedThumbnail = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ReaderLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we've just completed loading
    if (widget.isCompleted &&
        !oldWidget.isCompleted &&
        widget.onCompleted != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onCompleted!();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.filePath);
    final fileExtension = path.extension(widget.filePath).toLowerCase();
    final isTablet = ResponsiveConstants.isTablet(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background with blur effect
              if (_hasLoadedThumbnail && _thumbnailImage != null)
                Positioned.fill(
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _blurAnimation.value,
                        sigmaY: _blurAnimation.value,
                      ),
                      child: Opacity(
                        opacity: 0.3,
                        child: Image(
                          image: _thumbnailImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),

              // Content
              Positioned.fill(
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // File icon or thumbnail
                        if (_hasLoadedThumbnail && _thumbnailImage != null)
                          Container(
                            width: isTablet ? 240 : 180,
                            height: isTablet ? 320 : 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image(
                                image: _thumbnailImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: isTablet ? 180 : 140,
                            height: isTablet ? 180 : 140,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF352A3B)
                                  : const Color(0xFFF8F1F1),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                fileExtension == '.pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.book,
                                size: isTablet ? 80 : 60,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),

                        const SizedBox(height: 40),

                        // File name
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 22,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 24),

                        // Loading indicator
                        SizedBox(
                          width: isTablet ? 240 : 200,
                          child: widget.isCompleted
                              ? _buildCompletedIndicator(context)
                              : _buildProgressIndicator(context),
                        ),

                        const SizedBox(height: 16),

                        // Loading text
                        Text(
                          widget.isCompleted
                              ? 'Ready to read'
                              : 'Opening document...',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : const Color(0xFF9E7B80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final primaryColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFAA96B6)
        : const Color(0xFF9E7B80);

    final backgroundColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF352A3B)
        : const Color(0xFFF8F1F1);

    return Column(
      children: [
        LinearProgressIndicator(
          value: widget.loadingProgress > 0 ? widget.loadingProgress : null,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          borderRadius: BorderRadius.circular(8),
          minHeight: 8,
        ),
        if (widget.loadingProgress > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${(widget.loadingProgress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF2F2F7).withOpacity(0.7)
                  : const Color(0xFF1C1C1E).withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedIndicator(BuildContext context) {
    final primaryColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFAA96B6)
        : const Color(0xFF9E7B80);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Column(
          children: [
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF352A3B)
                  : const Color(0xFFF8F1F1),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Transform.scale(
              scale: value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
