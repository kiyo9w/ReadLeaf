import 'package:flutter/material.dart';
import '../blocs/FileBloc/file_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/services/webview.dart';


class BookInfoWidget extends StatelessWidget {
  final String link;
  final String? description;
  final double? fileSize;
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
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool hasRatings = ratings != null;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Color(0xffEBE6E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thumbnailUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child:Image.network(thumbnailUrl!, height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 10),
          Text(
            title ?? 'No Title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            author ?? 'Unknown Author',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          if (description != null)
            Text(
              description!,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 10),
            // if (hasRatings)
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     Text('${ratings} ★', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            //     const SizedBox(width: 10),
            //   ],
            // )
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                _buildChip(language ?? 'Unknown Language', Icons.language),
                const SizedBox(width: 8),
                _buildChip(_formatFileSize(fileSize), Icons.file_present),
              ],
            ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              onDownload();
            },
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              ),
              backgroundColor: MaterialStateProperty.all(const Color(0xFFF4F1EE)),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Adjust for rounded edges
                ),
              ),
              overlayColor: MaterialStateProperty.all(
                Colors.black12,
              ),
            ),
            icon: const Icon(
              Icons.download,
              color: Colors.black,
              size: 24,
            ),
            label: const Text(
              'Download',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
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
  Widget _buildChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label),
      backgroundColor: Colors.black87,
      labelStyle: const TextStyle(color: Colors.white),
    );

  }
}