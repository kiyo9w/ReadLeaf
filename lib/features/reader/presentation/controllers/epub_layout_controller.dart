import 'package:flutter/material.dart';
import 'package:read_leaf/features/reader/presentation/widgets/epub_viewer/epub_page_content.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/reader_settings_menu.dart';

/// Enum defining the different layout modes for the EPUB reader
enum EpubLayoutMode { longStrip, vertical, horizontal, facing }

/// Manages the layout and presentation of EPUB content
class EpubLayoutController {
  // Controllers for different layout modes
  late PageController verticalPageController;
  late PageController horizontalPageController;

  // Current state
  EpubLayoutMode _layoutMode;
  bool _isRightToLeftReadingOrder = false;
  double _fontSize;

  // Callback for when layout changes
  final Function(EpubLayoutMode)? onLayoutChanged;
  final Function(double)? onFontSizeChanged;

  /// Creates a new layout controller with the given initial mode
  EpubLayoutController({
    required int initialPage,
    EpubLayoutMode initialMode = EpubLayoutMode.longStrip,
    double initialFontSize = 23.0,
    this.onLayoutChanged,
    this.onFontSizeChanged,
  })  : _layoutMode = initialMode,
        _fontSize = initialFontSize {
    // Initialize controllers with the initial page
    verticalPageController = PageController(initialPage: initialPage - 1);
    horizontalPageController = PageController(initialPage: initialPage - 1);
  }

  /// Gets the current layout mode
  EpubLayoutMode get layoutMode => _layoutMode;

  /// Gets the current font size
  double get fontSize => _fontSize;

  /// Gets whether right-to-left reading is enabled
  bool get isRightToLeftReadingOrder => _isRightToLeftReadingOrder;

  /// Changes the layout mode
  void changeLayoutMode(EpubLayoutMode newMode) {
    if (_layoutMode == newMode) return;

    // Determine current page before changing
    final int currentPage = getCurrentPageIndex() + 1;

    _layoutMode = newMode;

    // Reset controllers to maintain position
    verticalPageController.dispose();
    horizontalPageController.dispose();

    verticalPageController = PageController(initialPage: currentPage - 1);
    horizontalPageController = PageController(initialPage: currentPage - 1);

    // Notify listeners
    if (onLayoutChanged != null) {
      onLayoutChanged!(newMode);
    }
  }

  /// Changes the font size
  void changeFontSize(double newSize) {
    if (_fontSize == newSize) return;

    _fontSize = newSize;

    // Notify listeners
    if (onFontSizeChanged != null) {
      onFontSizeChanged!(newSize);
    }
  }

  /// Sets the reading direction
  void setReadingDirection(bool isRightToLeft) {
    _isRightToLeftReadingOrder = isRightToLeft;
  }

  /// Gets the current page index from the relevant controller
  int getCurrentPageIndex() {
    switch (_layoutMode) {
      case EpubLayoutMode.vertical:
        return verticalPageController.hasClients
            ? verticalPageController.page?.round() ?? 0
            : 0;
      case EpubLayoutMode.horizontal:
      case EpubLayoutMode.facing:
        return horizontalPageController.hasClients
            ? horizontalPageController.page?.round() ?? 0
            : 0;
      case EpubLayoutMode.longStrip:
        // For long strip, the page is tracked elsewhere
        return 0;
    }
  }

  /// Jumps to a specific page
  void jumpToPage(int pageIndex) {
    switch (_layoutMode) {
      case EpubLayoutMode.vertical:
        if (verticalPageController.hasClients) {
          verticalPageController.jumpToPage(pageIndex - 1);
        }
        break;
      case EpubLayoutMode.horizontal:
      case EpubLayoutMode.facing:
        if (horizontalPageController.hasClients) {
          horizontalPageController.jumpToPage(pageIndex - 1);
        }
        break;
      case EpubLayoutMode.longStrip:
        // Handled by the scroll controller in the view
        break;
    }
  }

  /// Animates to a specific page
  Future<void> animateToPage(int pageIndex) async {
    switch (_layoutMode) {
      case EpubLayoutMode.vertical:
        if (verticalPageController.hasClients) {
          await verticalPageController.animateToPage(
            pageIndex - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        break;
      case EpubLayoutMode.horizontal:
      case EpubLayoutMode.facing:
        if (horizontalPageController.hasClients) {
          await horizontalPageController.animateToPage(
            pageIndex - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        break;
      case EpubLayoutMode.longStrip:
        // Handled by the scroll controller in the view
        break;
    }
  }

  /// Builds the appropriate layout widget based on the current mode
  Widget buildLayout({
    required List<EpubPageContent> pages,
    required Widget Function(EpubPageContent) pageBuilder,
    required BuildContext context,
  }) {
    switch (_layoutMode) {
      case EpubLayoutMode.vertical:
        return PageView(
          controller: verticalPageController,
          scrollDirection: Axis.vertical,
          children: pages.map(pageBuilder).toList(),
        );

      case EpubLayoutMode.horizontal:
        return PageView(
          controller: horizontalPageController,
          scrollDirection: Axis.horizontal,
          reverse: _isRightToLeftReadingOrder,
          children: pages.map(pageBuilder).toList(),
        );

      case EpubLayoutMode.facing:
        // Facing pages shows two pages side by side on larger screens
        final bool isLargeScreen = MediaQuery.of(context).size.width > 600;

        if (isLargeScreen) {
          // For large screens, pair pages together
          final List<Widget> pairedPages = [];
          for (int i = 0; i < pages.length; i += 2) {
            final List<Widget> pair = [];
            pair.add(Expanded(child: pageBuilder(pages[i])));

            if (i + 1 < pages.length) {
              pair.add(Expanded(child: pageBuilder(pages[i + 1])));
            } else {
              pair.add(const Expanded(child: SizedBox()));
            }

            pairedPages.add(Row(children: pair));
          }

          return PageView(
            controller: horizontalPageController,
            scrollDirection: Axis.horizontal,
            reverse: _isRightToLeftReadingOrder,
            children: pairedPages,
          );
        } else {
          // For small screens, use regular horizontal layout
          return PageView(
            controller: horizontalPageController,
            scrollDirection: Axis.horizontal,
            reverse: _isRightToLeftReadingOrder,
            children: pages.map(pageBuilder).toList(),
          );
        }

      case EpubLayoutMode.longStrip:
        // Long strip just places all content in a scrollable list
        return SingleChildScrollView(
          child: Column(
            children: pages.map(pageBuilder).toList(),
          ),
        );
    }
  }

  /// Disposes of controllers
  void dispose() {
    verticalPageController.dispose();
    horizontalPageController.dispose();
  }
}
