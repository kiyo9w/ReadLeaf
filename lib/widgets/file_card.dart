import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:path/path.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/DownloadBloc/download_bloc.dart';

class FileCard extends StatelessWidget {
  final String filePath;
  final int fileSize;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onView;
  final VoidCallback onRemove;
  final String title;

  final bool isInternetBook;
  final String? author;
  final String? thumbnailUrl;

  const FileCard({
    required this.filePath,
    required this.fileSize,
    required this.isSelected,
    required this.onSelected,
    required this.onView,
    required this.onRemove,
    required this.title,
    this.isInternetBook = false,
    this.author,
    this.thumbnailUrl,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayImageUrl = isInternetBook && thumbnailUrl != null
        ? thumbnailUrl!
        : 'https://picsum.photos/200/300?random=${DateTime.now().millisecondsSinceEpoch}';

    //   return BlocBuilder<DownloadBloc, DownloadState>(
    //     builder: (context, downloadState) {
    //       if (downloadState is DownloadInProgress && downloadState.message == filePath) {
    //         return _buildDownloadingCard(downloadState.progress);
    //       } else if (downloadState is DownloadCompleted && downloadState.filePath == filePath) {
    //         return _buildCompletedCard(context);
    //       }
    //       return _buildDefaultCard(context, displayImageUrl);
    //     },
    //   );
    // }
    //
    // Widget _buildDefaultCard(BuildContext context, String displayImageUrl) {
    return GestureDetector(
      onLongPress: onSelected,
      onTap: onView,
      child: Card(
        color: isSelected ? Colors.grey[200] : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  bottomLeft: Radius.circular(8.0),
                ),
                child: Image.network(
                  displayImageUrl,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  color: isSelected ? Colors.grey.withOpacity(0.5) : null,
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isInternetBook
                    ? _buildInternetBookInfo(context)
                    : _buildLocalFileInfo(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildDownloadingCard(double progress) {}
  //
  // Widget _buildCompletedCard(BuildContext context) {}

  Widget _buildLocalFileInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.grey[600] : Colors.black,
          ),
        ),
        const SizedBox(height: 8.0),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.check_box,
              color: Colors.blue,
              size: 24,
            ),
          ),
        Row(
          children: [
            Text(
              formatFileSize(fileSize),
              style: TextStyle(
                fontSize: 14.0,
                color: isSelected ? Colors.grey[500] : Colors.grey,
              ),
            ),
            const SizedBox(width: 8.0),
            const Text(
              'pdf',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {},
              child: Icon(
                Icons.star_border_outlined,
                color: Colors.yellow,
                size: 24.0,
                semanticLabel: 'Star',
              ),
            ),
            const SizedBox(width: 8.0),
            TextButton(
              onPressed: () {},
              child: Icon(
                Octicons.saved,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(width: 8.0),
            TextButton(
              onPressed: () {},
              child: Icon(
                FontAwesome5.readme,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInternetBookInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        if (author != null && author!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Author: $author',
              style: const TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                final downloadBloc = BlocProvider.of<DownloadBloc>(context);
                downloadBloc.add(StartDownload(url: filePath, fileName: title));
              },
            ),
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