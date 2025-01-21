import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';

class ThumbnailsView extends StatelessWidget {
  const ThumbnailsView({
    super.key,
    required this.documentRef,
    required this.controller,
  });

  final PdfDocumentRef? documentRef;
  final PdfViewerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade800,
      child: documentRef == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading pages...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : PdfDocumentViewBuilder(
              documentRef: documentRef!,
              builder: (context, document) => ListView.builder(
                itemCount: document?.pages.length ?? 0,
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  return Container(
                    margin: const EdgeInsets.all(8),
                    height: 240,
                    child: Column(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              // Update both controller and bloc
                              controller.goToPage(
                                pageNumber: pageNumber,
                                anchor: PdfPageAnchor.top,
                              );
                              context.read<ReaderBloc>().add(JumpToPage(pageNumber));
                              // Close the side nav after jumping to the page
                              context.read<ReaderBloc>().add(ToggleSideNav());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade600,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: PdfPageView(
                                  document: document,
                                  pageNumber: pageNumber,
                                  alignment: Alignment.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Page $pageNumber',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
