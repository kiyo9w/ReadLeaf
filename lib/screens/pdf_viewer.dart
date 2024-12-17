import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../blocs/FileBloc/file_bloc.dart';
import '../blocs/ReaderBloc/reader_bloc.dart';

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {
      },
      builder: (context, state) {
        if (state is ReaderLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ReaderError) {
          return Scaffold(
            body: Center(child: Text('Error: ${state.message}')),
          );
        }

        if (state is ReaderLoaded) {
          final currentPage = state.currentPage;
          final totalPages = state.totalPages;
          final showUI = state.showUI;
          final showSideNav = state.showSideNav;
          final file = state.file;

          Widget pdfViewer = SfPdfViewer.file(
            file,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            onDocumentLoaded: (details) {
            },
            onPageChanged: (details) {
              if (details.newPageNumber != currentPage) {
                context.read<ReaderBloc>().add(JumpToPage(details.newPageNumber));
              }
            },
          );

          return Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => context.read<ReaderBloc>().add(ToggleUIVisibility()),
                  child: pdfViewer,
                ),

                // Top app bar nav
                if (showUI)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppBar(
                      backgroundColor: const Color(0xffDDDDDD),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          context.read<ReaderBloc>().add(CloseReader());
                          context.read<FileBloc>().add(CloseViewer());
                          Navigator.pop(context);
                        },
                      ),
                      title: Text(
                        'Reading',
                        style: const TextStyle(fontSize: 20, color: Colors.black),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            context.read<ReaderBloc>().add(ToggleSideNav());
                          },
                        ),
                        PopupMenuButton<String>(
                          elevation: 0,
                          color: Color(0xffDDDDDD),
                          icon: const Icon(Icons.more_vert),
                          onSelected: (val) {
                            if (val == 'dark_mode') {
                              context.read<ReaderBloc>().add(ToggleReadingMode());
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'dark_mode',
                              child: Text('Dark mode'),
                            ),
                            const PopupMenuItem(
                              value: 'move_trash',
                              child: Text('Move file to trash'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share file'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // bottom book nav
                if (showUI)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Color(0xffDDDDDD),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            '$currentPage',
                            style: const TextStyle(color: Colors.black),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Slider(
                              value: currentPage.toDouble(),
                              min: 1,
                              max: totalPages.toDouble(),
                              activeColor: Colors.pinkAccent,
                              inactiveColor: Colors.white54,
                              onChanged: (value) {
                                context.read<ReaderBloc>().add(JumpToPage(value.toInt()));
                                _pdfViewerController.jumpToPage(value.toInt());
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$totalPages',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: 0,
                  bottom: 0,
                  right: showSideNav ? 0 : -250,
                  child: Container(
                    width: 250,
                    color: Colors.grey.shade800.withOpacity(0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBar(
                          title: const Text('Chapters'),
                          backgroundColor: Colors.grey.shade800,
                          automaticallyImplyLeading: false,
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                context.read<ReaderBloc>().add(ToggleSideNav());
                              },
                            )
                          ],
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              _buildChapterItem('Layout widgets', 55),
                              _buildChapterItem('Navigation widgets', 55),
                              _buildChapterItem('Other widgets', 56),
                              _buildChapterItem('How to create your own stateless...', 65),
                              _buildChapterItem('Conclusion', 69),
                              _buildChapterItem('Chapter 7: Index', 85),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return const Scaffold();
      },
    );
  }

  Widget _buildChapterItem(String title, int page) {
    return BlocBuilder<ReaderBloc, ReaderState>(
      builder: (context, state) {
        return ListTile(
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: Text(
            '$page',
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () {
            context.read<ReaderBloc>().add(JumpToPage(page));
            _pdfViewerController.jumpToPage(page);
            context.read<ReaderBloc>().add(ToggleSideNav());
          },
        );
      },
    );
  }
}