import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:path/path.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:migrated/services/book_metadata_repository.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/services/thumbnail_service.dart';
import 'package:migrated/services/thumbnail_service.dart';
import 'package:get_it/get_it.dart';
import 'package:migrated/themes/custom_theme_extension.dart';

class FileCard extends StatefulWidget {
  final String filePath;
  final int fileSize;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onView;
  final VoidCallback onRemove;
  final VoidCallback onDownload;
  final VoidCallback onStar;
  final String title;
  final bool isInternetBook;
  final String? author;
  final String? thumbnailUrl;
  final bool isStarred;
  final bool canDismiss;

  const FileCard({
    required this.filePath,
    required this.fileSize,
    required this.isSelected,
    required this.onSelected,
    required this.onView,
    required this.onRemove,
    required this.title,
    required this.onDownload,
    required this.onStar,
    this.isInternetBook = false,
    this.author,
    this.thumbnailUrl,
    this.isStarred = false,
    this.canDismiss = true,
    Key? key,
  }) : super(key: key);

  static String extractFileName(String filePath) {
    return basename(filePath).replaceAll(RegExp(r'\.[^/.]+$'), '');
  }

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  late Future<ImageProvider> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _initThumbnailFuture();
  }

  @override
  void didUpdateWidget(FileCard oldWidget) {
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
        : ThumbnailService().getPdfThumbnail(widget.filePath);
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

  Widget _buildThumbnail() {
    return FutureBuilder<ImageProvider>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Icon(
              widget.isInternetBook ? Icons.error : Icons.picture_as_pdf,
            ),
          );
        }
        return Image(
          image: snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              widget.isInternetBook ? Icons.error : Icons.picture_as_pdf,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    Widget content = GestureDetector(
      onLongPress: widget.onSelected,
      onTap: widget.onView,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: customTheme?.fileCardBackground ?? theme.cardColor,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 128.5,
              height: 190 + 1,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.dividerColor,
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnail(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.isInternetBook
                  ? _buildInternetBookInfo(context)
                  : _buildLocalFileInfo(context),
            ),
          ],
        ),
      ),
    );

    if (widget.canDismiss) {
      return Dismissible(
        key: Key(widget.filePath),
        direction: DismissDirection.horizontal,
        onDismissed: (direction) {
          widget.onRemove();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.title} removed')),
          );
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildLocalFileInfo(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final progress = _getReadingProgress();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: widget.isSelected
                      ? theme.disabledColor
                      : customTheme?.fileCardText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            if (widget.isSelected)
              Icon(
                Icons.check_box,
                color: theme.primaryColor,
                size: 24.0,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.author ?? "Unknown Author",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: customTheme?.fileCardText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          "PDF, ${formatFileSize(widget.fileSize)}",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: widget.isSelected
                ? theme.disabledColor
                : customTheme?.fileCardText?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 62),
        LinearPercentIndicator(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          lineHeight: 4.0,
          percent: progress,
          backgroundColor: theme.primaryColor.withOpacity(0.2),
          progressColor: theme.primaryColor,
          barRadius: const Radius.circular(1),
        ),
        const SizedBox(height: 6),
        Text(
          _getProgressText(),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: theme.primaryColor,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                widget.isStarred ? Icons.star : Icons.star_border_outlined,
                color:
                    widget.isStarred ? Colors.amber : customTheme?.fileCardText,
                size: 24.0,
              ),
              onPressed: widget.onStar,
            ),
            const SizedBox(width: 36.0),
            IconButton(
              icon: Icon(
                FontAwesome5.check,
                color: customTheme?.fileCardText,
                size: 20.0,
              ),
              onPressed: widget.onRemove,
            ),
            const SizedBox(width: 22.0),
            Icon(
              Icons.more_vert,
              color: customTheme?.fileCardText,
              size: 30.0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInternetBookInfo(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: widget.isSelected
                      ? theme.disabledColor
                      : customTheme?.fileCardText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            if (widget.isSelected)
              Icon(
                Icons.check_box,
                color: theme.primaryColor,
                size: 24.0,
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (widget.author != null && widget.author!.isNotEmpty)
          Text(
            widget.author!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customTheme?.fileCardText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 62),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.star_border_outlined,
              color: customTheme?.fileCardText,
              size: 24.0,
              semanticLabel: 'Star',
            ),
            const SizedBox(width: 22.0),
            IconButton(
              onPressed: widget.onDownload,
              icon: Icon(
                Icons.download,
                color: customTheme?.fileCardText,
                size: 30.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes} B';
    } else if (bytes < 1000000) {
      return '${(bytes / 1000).toStringAsFixed(2)} KB';
    } else if (bytes < 1000000000) {
      return '${(bytes / 1000000).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
    }
  }
}
