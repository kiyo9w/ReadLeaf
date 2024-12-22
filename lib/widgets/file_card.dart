import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:path/path.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FileCard extends StatelessWidget {
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
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayImageUrl = isInternetBook && thumbnailUrl != null
        ? thumbnailUrl!
        : 'https://picsum.photos/200/300?random=${DateTime.now().millisecondsSinceEpoch}';

    return Dismissible(
      key: Key(filePath),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        onRemove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title removed')),
        );
      },
      child: GestureDetector(
        onLongPress: onSelected,
        onTap: onView,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5F4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 128.5,
                height: 190 + 1,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black,
                    width: 0.5, // Thin border width
                  ),
                ),
                child: Image.network(
                  displayImageUrl,
                  width: 135,
                  height: 190,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isInternetBook
                    ? _buildInternetBookInfo(context)
                    : _buildLocalFileInfo(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalFileInfo(BuildContext context) {
    final hardCodedAuthor = "Yuval Noah Harari";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.normal,
                  color: isSelected ? Colors.grey[600] : Colors.black,
                ),
                maxLines: 1, // Limit to one line
                overflow:
                    TextOverflow.ellipsis, // Add ellipsis if text overflows
              ),
            ),
            const SizedBox(width: 8.0),
            if (isSelected)
              Icon(
                Icons.check_box,
                color: Colors.blue,
                size: 24.0,
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Author
        Text(
          hardCodedAuthor,
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.normal,
            color: Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // File info (PDF, size)
        Text(
          "PDF, ${formatFileSize(fileSize)}",
          style: TextStyle(
            fontSize: 14.0,
            color: isSelected ? Colors.grey[600] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 62),
        Row(
          children: [
            _buildDot(Colors.brown.shade300),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 1,
                color: Colors.brown.shade300,
              ),
            ),
            _buildDot(Colors.brown.shade300),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 1,
                color: Colors.brown.shade300,
              ),
            ),
            _buildDot(Colors.brown.shade300),
          ],
        ),
        const SizedBox(height: 22),
        // Icons at the bottom (Star and a check icon)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                isStarred ? Icons.star : Icons.star_border_outlined,
                color: isStarred ? Colors.amber : Colors.black87,
                size: 24.0,
              ),
              onPressed: () {
                onStar();
              },
            ),
            const SizedBox(width: 36.0),
            IconButton(
              icon: Icon(
                FontAwesome5.check,
                color: Colors.black87,
                size: 20.0,
              ),
              onPressed: () {
                onRemove();
              },
            ),
            const SizedBox(width: 22.0),
            Icon(
              Icons.more_vert,
              color: Colors.black87,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.normal,
                  color: isSelected ? Colors.grey[600] : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            if (isSelected)
              Icon(
                Icons.check_box,
                color: Colors.blue,
                size: 24.0,
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (author != null && author!.isNotEmpty)
          Text(
            author!,
            style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 62),
        Row(
          children: [
            _buildDot(Colors.brown.shade300),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 1,
                color: Colors.brown.shade300,
              ),
            ),
            _buildDot(Colors.brown.shade300),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 1,
                color: Colors.brown.shade300,
              ),
            ),
            _buildDot(Colors.brown.shade300),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.star_border_outlined,
              color: Colors.black87,
              size: 24.0,
              semanticLabel: 'Star',
            ),
            const SizedBox(width: 22.0),
            IconButton(
                onPressed: () {
                  onDownload();
                },
                icon: Icon(
                  Icons.download,
                  color: Colors.black87,
                  size: 30.0,
                )),
          ],
        ),
      ],
    );
  }

  static String extractFileName(String filePath) {
    File file = File(filePath);
    return basename(file.path);
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
