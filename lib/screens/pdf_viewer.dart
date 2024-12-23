import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/widgets/text_search_view.dart';

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final _controller = PdfViewerController();
  late final _textSearcher = PdfTextSearcher(_controller)..addListener(_update);
  bool _showSearchPanel = false;
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    });
  }

  @override
  void dispose() {
    _textSearcher.removeListener(_update);
    _textSearcher.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });
    super.dispose();
  }

  void _closeSearchPanel() {
    setState(() {
      _showSearchPanel = false;
      _textSearcher.resetTextSearch();
    });
  }

  void _toggleSearchPanel() {
    setState(() {
      _showSearchPanel = !_showSearchPanel;
      if (!_showSearchPanel) {
        _textSearcher.resetTextSearch();
      }
    });
  }

  void _closeSideNav(BuildContext context) {
    final readerBloc = context.read<ReaderBloc>();
    final state = readerBloc.state;
    if (state is ReaderLoaded && state.showSideNav) {
      readerBloc.add(ToggleSideNav());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {},
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

          Widget pdfViewer = PdfViewer.file(
            file.path,
            controller: _controller,
            params: PdfViewerParams(
              pagePaintCallbacks: [
                _textSearcher.pageTextMatchPaintCallback,
              ],
              viewerOverlayBuilder: (context, size, handleLinkTap) => [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    _controller.zoomUp(loop: true);
                  },
                  onTapUp: (details) {
                    handleLinkTap(details.localPosition);
                  },
                  // onScaleStart: (details) {
                  //   _baseScaleFactor = _scaleFactor;
                  // },
                  // onScaleUpdate: (details) {
                  //   setState(() {
                  //     _scaleFactor = _baseScaleFactor * details.scale;
                  //     _controller.setZoom(
                  //         details.localFocalPoint, _scaleFactor);
                  //   });
                  // },
                  child: IgnorePointer(
                    child: SizedBox(width: size.width, height: size.height),
                  ),
                ),
              ],
            ),
          );

          return Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<ReaderBloc>().add(ToggleUIVisibility());
                    if (_showSearchPanel) _closeSearchPanel();
                    if (showSideNav) _closeSideNav(context);
                  },
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
                      title: const Text(
                        'Reading',
                        style: TextStyle(fontSize: 20, color: Colors.black),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _toggleSearchPanel,
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            context.read<ReaderBloc>().add(ToggleSideNav());
                          },
                        ),
                        PopupMenuButton<String>(
                          elevation: 0,
                          color: const Color(0xffDDDDDD),
                          icon: const Icon(Icons.more_vert),
                          onSelected: (val) {
                            if (val == 'dark_mode') {
                              context
                                  .read<ReaderBloc>()
                                  .add(ToggleReadingMode());
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
                      color: const Color(0xffDDDDDD),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
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
                                final page = value.toInt();
                                context
                                    .read<ReaderBloc>()
                                    .add(JumpToPage(page));
                                _controller.goToPage(pageNumber: page);
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

                // Side navigation
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: 0,
                  bottom: 0,
                  left: showSideNav ? 0 : -250,
                  child: Container(
                    width: 250,
                    color: Colors.grey.shade700.withOpacity(0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBar(
                          title: const Text('Chapters',
                              style: TextStyle(color: Colors.white70)),
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
                              _buildChapterItem(
                                  'How to create your own stateless...', 65),
                              _buildChapterItem('Conclusion', 69),
                              _buildChapterItem('Chapter 7: Index', 85),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search panel
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: 0,
                  bottom: 0,
                  left: _showSearchPanel ? 0 : -300,
                  child: SizedBox(
                    width: 300,
                    child: TextSearchView(
                      textSearcher: _textSearcher,
                      onClose: _closeSearchPanel,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return const Scaffold(
          body: Center(child: Text('No content')),
        );
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
            _controller.goToPage(pageNumber: page);
            context.read<ReaderBloc>().add(ToggleSideNav());
          },
        );
      },
    );
  }
}
