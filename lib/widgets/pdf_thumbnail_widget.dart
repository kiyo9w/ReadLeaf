import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfThumbnailWidget extends StatelessWidget {
  final String filePath;
  final double width;
  final double height;

  const PdfThumbnailWidget({
    required this.filePath,
    required this.width,
    required this.height,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: PdfDocumentViewBuilder.file(
        filePath,
        builder: (context, document) {
          if (document == null) {
            return Container(
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.picture_as_pdf)),
            );
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
      ),
    );
  }
}
