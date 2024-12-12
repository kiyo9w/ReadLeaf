import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/octicons_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart';

class FileCard extends StatelessWidget {
  final String filePath;
  final int fileSize;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onView;
  final VoidCallback onRemove;
  final String imageUrl = 'https://link.springer.com/book/10.1007/978-1-4842-5181-2';
  final String title;
  final String fileType = 'pdf';
  final double progress = 10.7;

  const FileCard({
    required this.filePath,
    required this.fileSize,
    required this.isSelected,
    required this.onSelected,
    required this.onView,
    required this.onRemove,
    required this.title,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  imageUrl,
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
                child: Column(
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
                          MdiIcons.fromString('checkbox-marked'),
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                    Row(
                      children: [
                        Text(
                          fileSize != null ? formatFileSize(fileSize) : "Empty",
                          style: TextStyle(
                            fontSize: 14.0,
                            color: isSelected ? Colors.grey[500] : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          fileType,
                          style: TextStyle(
                            fontSize: 14.0,
                            color: isSelected ? Colors.grey[500] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1.0),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: isSelected ? Colors.grey[300] : Colors.grey[200],
                        color: isSelected ? Colors.grey[500] : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Add your button logic here
                          },
                          child: Icon(
                            Icons.star_border_outlined,
                            color: Colors.yellow,
                            size: 24.0,
                            semanticLabel: 'Star',
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {

                          },
                          child: Icon(
                              Octicons.saved,
                              color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {

                          },
                          child: Icon(
                            FontAwesome5.readme,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String extractFileName(String filePath) {
    File file = new File(filePath);
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