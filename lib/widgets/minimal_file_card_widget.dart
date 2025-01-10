import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'dart:io';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:migrated/services/book_metadata_repository.dart';
import 'package:get_it/get_it.dart';

class MinimalFileCard extends StatelessWidget {
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

  double _getReadingProgress() {
    final metadata = GetIt.I<BookMetadataRepository>().getMetadata(filePath);
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
    if (isInternetBook && thumbnailUrl != null) {
      return Image.network(
        thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.book, size: 40, color: Colors.black26),
        ),
      );
    }

    return PdfDocumentViewBuilder.file(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getReadingProgress();

    return GestureDetector(
      onTap: onTap,
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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (author != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    author!,
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
                    context.read<FileBloc>().add(RemoveFile(filePath));
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
                lineHeight: 2.0,
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
