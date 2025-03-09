import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:read_leaf/features/reader/presentation/widgets/epub_viewer/epub_page_content.dart';

/// A widget for rendering EPUB content in a continuous scrollable view
/// without page divisions, optimized for the long strip reading mode.
class ContinuousReaderView extends StatefulWidget {
  /// The flattened list of pages to display
  final List<EpubPageContent> pages;

  /// The current font size
  final double fontSize;

  /// Controller for scrolling to specific items
  final ItemScrollController scrollController;

  /// Listener for item positions
  final ItemPositionsListener positionsListener;

  /// Callback when a link is tapped
  final Function(String)? onLinkTap;

  const ContinuousReaderView({
    super.key,
    required this.pages,
    required this.fontSize,
    required this.scrollController,
    required this.positionsListener,
    this.onLinkTap,
  });

  @override
  State<ContinuousReaderView> createState() => _ContinuousReaderViewState();
}

class _ContinuousReaderViewState extends State<ContinuousReaderView> {
  // Group pages by chapter to reduce widgets and improve performance
  Map<int, List<EpubPageContent>> _groupedPages = {};

  @override
  void initState() {
    super.initState();
    _groupPagesByChapter();
  }

  @override
  void didUpdateWidget(ContinuousReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _groupPagesByChapter();
    }
  }

  void _groupPagesByChapter() {
    _groupedPages = {};

    for (final page in widget.pages) {
      if (!_groupedPages.containsKey(page.chapterIndex)) {
        _groupedPages[page.chapterIndex] = [];
      }
      _groupedPages[page.chapterIndex]!.add(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      itemCount: widget.pages.length,
      itemScrollController: widget.scrollController,
      itemPositionsListener: widget.positionsListener,
      itemBuilder: (context, index) {
        final page = widget.pages[index];

        // Check if this is the first page of a chapter
        final isFirstPageInChapter = page.pageNumberInChapter == 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show chapter title for first page in chapter
              if (isFirstPageInChapter)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                  child: Text(
                    page.chapterTitle,
                    style: TextStyle(
                      fontSize: widget.fontSize * 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Render the HTML content
              HtmlWidget(
                page.content,
                textStyle: TextStyle(
                  fontSize: widget.fontSize,
                  height: 1.5,
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'p') {
                    return {'margin': '0 0 8px 0', 'text-indent': '1.5em'};
                  }
                  return null;
                },
                onTapUrl: (url) {
                  if (widget.onLinkTap != null) {
                    widget.onLinkTap!(url);
                  }
                  return true;
                },
              ),

              // Add a small gap between pages
              SizedBox(height: 8.0),
            ],
          ),
        );
      },
    );
  }
}
