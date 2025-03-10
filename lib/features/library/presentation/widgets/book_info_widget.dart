import 'package:flutter/material.dart';

class BookInfoWidget extends StatelessWidget {
  final String link;
  final String? description;
  final double? fileSize;
  final String? fileType;
  final String? title;
  final double ratings;
  final String? language;
  final String? genre;

  final bool isInternetBook;
  final String? author;
  final String? thumbnailUrl;
  final VoidCallback onDownload;

  const BookInfoWidget({
    required this.fileSize,
    required this.language,
    required this.link,
    required this.description,
    required this.title,
    required this.ratings,
    required this.genre,
    required this.onDownload,
    this.isInternetBook = false,
    this.author,
    this.thumbnailUrl,
    this.fileType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thumbnailUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Image.network(
                thumbnailUrl!,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: theme.primaryColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        Icons.error_outline,
                        size: 40,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Text(
            title ?? 'No Title',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            author ?? 'Unknown Author',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          if (description != null)
            Text(
              description!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChip(
                  context, language ?? 'Unknown Language', Icons.language),
              const SizedBox(width: 8),
              _buildChip(
                  context, _formatFileSize(fileSize), Icons.file_present),
              const SizedBox(width: 8),
              _buildChip(
                  context, fileType ?? 'Unknown Type', Icons.description),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onDownload,
            style: FilledButton.styleFrom(
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.white12
                  : Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(
              Icons.download,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.white,
              size: 24,
            ),
            label: Text(
              'Download',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(double? sizeInMB) {
    if (sizeInMB == null) return '';
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }

  Widget _buildChip(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: Colors.white,
      ),
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
      backgroundColor: isDark ? Colors.white12 : Colors.black87,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
