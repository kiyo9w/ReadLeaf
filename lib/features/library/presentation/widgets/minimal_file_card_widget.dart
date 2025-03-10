import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/library/data/thumbnail_service.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/core/themes/custom_theme_extension.dart';

class MinimalFileCard extends StatefulWidget {
  final String filePath;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final bool isInternetBook;

  const MinimalFileCard({
    super.key,
    required this.filePath,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.onTap,
    this.isInternetBook = false,
  });

  @override
  State<MinimalFileCard> createState() => _MinimalFileCardState();
}

class _MinimalFileCardState extends State<MinimalFileCard> {
  late Future<ImageProvider> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _initThumbnailFuture();
  }

  @override
  void didUpdateWidget(MinimalFileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath ||
        widget.thumbnailUrl != oldWidget.thumbnailUrl ||
        widget.isInternetBook != oldWidget.isInternetBook) {
      _initThumbnailFuture();
    }
  }

  void _initThumbnailFuture() {
    _thumbnailFuture = widget.isInternetBook && widget.thumbnailUrl != null
        ? ThumbnailService().getNetworkThumbnail(widget.thumbnailUrl!)
        : ThumbnailService().getFileThumbnail(widget.filePath);
  }

  double _getReadingProgress() {
    final metadata =
        GetIt.I<BookMetadataRepository>().getMetadata(widget.filePath);
    if (metadata != null) {
      return metadata.readingProgress;
    }
    return 0.0;
  }

  String _getProgressText() {
    final progress = _getReadingProgress();
    return '${(progress * 100).toInt()}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final progress = _getReadingProgress();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor, width: 0.5),
                    color: customTheme?.minimalFileCardBackground ??
                        theme.cardColor,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumbnail(),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: customTheme?.minimalFileCardText,
                  ),
                ),
                if (widget.author != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: customTheme?.minimalFileCardText.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              top: -8,
              right: -8,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: customTheme?.minimalFileCardText.withOpacity(0.7),
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('File deleted'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            context
                                .read<FileBloc>()
                                .add(const UndoRemoveFile());
                          },
                        ),
                      ),
                    );

                    // Then handle state update
                    context.read<FileBloc>().add(RemoveFile(widget.filePath));
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: LinearPercentIndicator(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                lineHeight: 4.0,
                percent: progress,
                backgroundColor: theme.primaryColor.withOpacity(0.2),
                progressColor: theme.primaryColor,
                barRadius: const Radius.circular(1),
                center: Text(
                  _getProgressText(),
                  style: TextStyle(
                    fontSize: 8,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return FutureBuilder<ImageProvider>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: theme.primaryColor,
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Icon(
              widget.isInternetBook ? Icons.book : Icons.picture_as_pdf,
              size: 40,
              color: customTheme?.minimalFileCardText.withOpacity(0.3),
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Image(
            image: snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                widget.isInternetBook ? Icons.book : Icons.picture_as_pdf,
                size: 40,
                color: customTheme?.minimalFileCardText.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }
}
