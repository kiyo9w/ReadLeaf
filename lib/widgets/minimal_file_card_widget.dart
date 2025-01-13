import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/services/thumbnail_service.dart';
import 'dart:io';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:migrated/services/book_metadata_repository.dart';
import 'package:get_it/get_it.dart';

class MinimalFileCard extends StatefulWidget {
  final String filePath;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final bool isInternetBook;

  const MinimalFileCard({
    Key? key,
    required this.filePath,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.onTap,
    this.isInternetBook = false,
  }) : super(key: key);

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
              widget.isInternetBook ? Icons.book : Icons.picture_as_pdf,
              size: 40,
              color: Colors.black26,
            ),
          );
        }
        return Image(
          image: snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              widget.isInternetBook ? Icons.book : Icons.picture_as_pdf,
              size: 40,
              color: Colors.black26,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    border: Border.all(color: Colors.black12, width: 0.5),
                    color: Colors.grey[100],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumbnail(),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.author != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                  color: Colors.black54,
                  onPressed: () {
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
                backgroundColor: Colors.brown.shade100,
                progressColor: Colors.brown.shade300,
                barRadius: const Radius.circular(1),
                center: Text(
                  _getProgressText(),
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.brown.shade300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
