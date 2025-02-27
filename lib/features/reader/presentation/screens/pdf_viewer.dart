import 'dart:io';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/widgets/text_search_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/companion_chat/presentation/widgets/floating_chat_widget.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/core/utils/utils.dart';
import 'package:read_leaf/features/reader/presentation/widgets/side_menu/pdf/markers_view.dart';
import 'package:read_leaf/features/reader/presentation/widgets/side_menu/pdf/outline_view.dart';
import 'package:read_leaf/features/reader/presentation/widgets/side_menu/pdf/thumbnails_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/floating_selection_menu.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/full_selection_menu.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/reader_settings_menu.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/reader_loading_screen.dart';
import 'dart:async';
import 'package:material_symbols_icons/material_symbols_icons.dart';

enum PdfLayoutMode { vertical, horizontal, facing }

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({super.key});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PdfViewerController();
  late final _textSearcher = PdfTextSearcher(_controller)..addListener(_update);
  late final _geminiService = GetIt.I<GeminiService>();
  late final _characterService = GetIt.I<AiCharacterService>();
  late final TabController _tabController;
  final GlobalKey<FloatingChatWidgetState> _floatingChatKey = GlobalKey();
  OverlayEntry? _floatingMenuEntry;
  Timer? _floatingMenuTimer;
  Offset? _lastPointerDownPosition;
  bool _showSearchPanel = false;
  bool _isZoomedIn = false;
  bool _showAskAiButton = false;
  final bool _isLoadingAiResponse = false;
  String? _selectedText;
  final double _scaleFactor = 1.0;
  final double _baseScaleFactor = 1.0;
  final _markers = <int, List<Marker>>{};
  List<PdfTextRanges>? _textSelections;
  final outline = ValueNotifier<List<PdfOutlineNode>?>(null);
  final documentRef = ValueNotifier<PdfDocumentRef?>(null);
  Key _searchViewKey = UniqueKey();
  Timer? _sliderDwellTimer;
  int? _lastSliderValue;
  bool _isSliderInteracting = false;
  PdfLayoutMode _layoutMode = PdfLayoutMode.vertical;
  final bool _isRightToLeftReadingOrder = false;
  final bool _needCoverPage = true;
  final bool _isInitialLoading = true;
  final double _loadingProgress = 0.0;

  String get _currentTitle {
    switch (_tabController.index) {
      case 0:
        return 'Table of Contents';
      case 1:
        return 'Highlights and Notes';
      case 2:
        return 'Thumbnails';
      default:
        return 'Table of Contents';
    }
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Add controller ready listener using a safer approach
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.addListener(_onControllerReady);
        _textSearcher.addListener(_update);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NavScreen.globalKey.currentState?.hideNavBar(true);
      }
    });
  }

  void _onControllerReady() {
    if (_controller.isReady && mounted) {
      _loadHighlights();
      try {
        _controller.removeListener(_onControllerReady);
      } catch (e) {
        print('Error removing controller ready listener: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isReady && mounted) {
      _loadHighlights();
    }
  }

  void _loadHighlights() async {
    if (!_controller.isReady || !mounted) {
      return;
    }

    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      final highlights = state.metadata.highlights;

      final Map<int, List<Marker>> newMarkers = {};

      for (final highlight in highlights) {
        try {
          final pageText =
              await _textSearcher.loadText(pageNumber: highlight.pageNumber);
          if (pageText != null) {
            final index = pageText.fullText.indexOf(highlight.text);
            if (index != -1) {
              final textRange = PdfTextRanges(
                pageText: pageText,
                ranges: [
                  PdfTextRange(start: index, end: index + highlight.text.length)
                ],
              );

              newMarkers
                  .putIfAbsent(highlight.pageNumber, () => [])
                  .add(Marker(Colors.yellow, textRange));
            } else {
              final normalizedPageText =
                  pageText.fullText.replaceAll(RegExp(r'\s+'), ' ').trim();
              final normalizedHighlightText =
                  highlight.text.replaceAll(RegExp(r'\s+'), ' ').trim();
              final fuzzyIndex =
                  normalizedPageText.indexOf(normalizedHighlightText);

              if (fuzzyIndex != -1) {
                final textRange = PdfTextRanges(
                  pageText: pageText,
                  ranges: [
                    PdfTextRange(
                        start: fuzzyIndex,
                        end: fuzzyIndex + normalizedHighlightText.length)
                  ],
                );

                newMarkers
                    .putIfAbsent(highlight.pageNumber, () => [])
                    .add(Marker(Colors.yellow, textRange));
              }
            }
          }
        } catch (e) {
          dev.log('Error loading highlight: $e');
        }
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sliderDwellTimer?.cancel();
    try {
      _controller.removeListener(_onControllerReady);
      _textSearcher.removeListener(_update);
    } catch (e) {
      print('Error removing listeners: $e');
    }
    _textSearcher.dispose();
    outline.dispose();
    documentRef.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NavScreen.globalKey.currentState?.hideNavBar(false);
      }
    });
    super.dispose();
  }

  Future<bool> _shouldOpenUrl(BuildContext context, Uri url) async {
    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Navigate to URL?'),
          content: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text:
                        'Do you want to navigate to the following location?\n',
                  ),
                  TextSpan(
                    text: url.toString(),
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _handleLink(PdfLink link) async {
    if (link.url != null) {
      final shouldOpen = await _shouldOpenUrl(context, link.url!);
      if (shouldOpen && mounted) {
        launchUrl(link.url!);
      }
    } else if (link.dest != null) {
      _controller.goToPage(pageNumber: link.dest!.pageNumber);
    }
  }

  void _closeSearchPanel() {
    setState(() {
      _showSearchPanel = false;
      _textSearcher.resetTextSearch();
    });
  }

  void _toggleSearchPanel() {
    setState(() {
      // Close side nav if it's open
      if (context.read<ReaderBloc>().state is ReaderLoaded) {
        final state = context.read<ReaderBloc>().state as ReaderLoaded;
        if (state.showSideNav) {
          context.read<ReaderBloc>().add(ToggleSideNav());
        }
      }

      _showSearchPanel = !_showSearchPanel;
      if (_showSearchPanel) {
        _searchViewKey = UniqueKey();
      } else {
        _textSearcher.resetTextSearch();
      }
    });
  }

  void _closeSideNav(BuildContext context) {
    final readerBloc = context.read<ReaderBloc>();
    final state = readerBloc.state;
    if (state is ReaderLoaded && state.showSideNav) {
      // Close search panel if it's open
      if (_showSearchPanel) {
        setState(() {
          _showSearchPanel = false;
          _textSearcher.resetTextSearch();
        });
      }
      readerBloc.add(ToggleSideNav());
    }
  }

  void _toggleSideNav() {
    final readerBloc = context.read<ReaderBloc>();
    final state = readerBloc.state;
    if (state is ReaderLoaded) {
      // If search panel is open, close it first
      if (_showSearchPanel) {
        setState(() {
          _showSearchPanel = false;
          _textSearcher.resetTextSearch();
        });
      }
      readerBloc.add(ToggleSideNav());
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final zoomCenter = details.localPosition;
    setState(() {
      if (_isZoomedIn) {
        _controller.zoomDown(loop: false);
        _isZoomedIn = false;
      } else {
        _controller.zoomUp(loop: false);
        _isZoomedIn = true;
      }
    });
  }

  void _handleTap() {
    // Close any open side widgets first
    if (_showSearchPanel) {
      _closeSearchPanel();
    }
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      if (state.showSideNav) {
        _closeSideNav(context);
      }
    }
    // Toggle UI visibility after handling side widgets
    context.read<ReaderBloc>().add(ToggleUIVisibility());
  }

  void _handleTextSelectionChange(List<PdfTextRanges> selections) {
    if (selections.isNotEmpty &&
        selections.any((range) => range.text.trim().isNotEmpty)) {
      final selectedText = selections
          .map((range) => range.text.trim())
          .where((text) => text.isNotEmpty)
          .join(' ');

      setState(() {
        _selectedText = selectedText;
        _textSelections = selections;
      });

      // We'll let the onPointerUp event handle showing the menu
      // instead of showing it here, to ensure proper positioning
    } else {
      setState(() {
        _selectedText = null;
        _textSelections = null;
      });
      _removeFloatingMenu();
    }
  }

  void _addCurrentSelectionToMarkers(Color color) {
    if (_controller.isReady && _textSelections != null) {
      for (final selectedText in _textSelections!) {
        dev.log(
            'Processing selection: ${selectedText.text} on page ${selectedText.pageNumber}');
        _markers
            .putIfAbsent(selectedText.pageNumber, () => [])
            .add(Marker(color, selectedText));

        // Save highlight to BookMetadata
        context.read<ReaderBloc>().add(AddHighlight(
              text: selectedText.text,
              note: null,
              pageNumber: selectedText.pageNumber,
            ));
      }
      setState(() {});
    }
  }

  void _deleteMarker(Marker marker) {
    _markers[marker.ranges.pageNumber]!.remove(marker);

    // Remove highlight from BookMetadata
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      final updatedHighlights = state.metadata.highlights
          .where((h) =>
              h.text != marker.ranges.text ||
              h.pageNumber != marker.ranges.pageNumber)
          .toList();

      final updatedMetadata =
          state.metadata.copyWith(highlights: updatedHighlights);
      context.read<ReaderBloc>().add(UpdateMetadata(updatedMetadata));
    }

    setState(() {});
  }

  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markersList = _markers[page.pageNumber];
    if (markersList == null || markersList.isEmpty) {
      return;
    }
    final markersCopy = List<Marker>.from(markersList);

    for (final marker in markersCopy) {
      final paint = Paint()
        ..color = marker.color.withAlpha(100)
        ..style = PaintingStyle.fill;

      for (final range in marker.ranges.ranges) {
        final f = PdfTextRangeWithFragments.fromTextRange(
          marker.ranges.pageText,
          range.start,
          range.end,
        );
        if (f != null) {
          canvas.drawRect(
            f.bounds.toRectInPageRect(page: page, pageRect: pageRect),
            paint,
          );
        }
      }
    }
  }

  Future<void> _handleChatMessage(String? message,
      {String? selectedText}) async {
    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) {
      return;
    }

    final bookTitle = path.basename(state.file.path);
    final currentPage = state.currentPage;
    final totalPages = state.totalPages;

    try {
      final response = await _geminiService.askAboutText(
        selectedText ?? '',
        customPrompt: message ??
            'Can you explain what the text is about? After that share your thoughts in a single open ended question in the same paragraph, make the question short and concise.',
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: message == null ? 'encouragement' : 'analyze_text',
      );

      if (!mounted) return;

      if (_floatingChatKey.currentState != null) {
        _floatingChatKey.currentState!.addAiResponse(response);
      }
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorSnackBar(context, 'Failed to get AI response');
      dev.log('Error in _handleChatMessage: $e');
    }
  }

  PdfPageLayout _handleLayoutPages(
      List<PdfPage> pages, PdfViewerParams params) {
    switch (_layoutMode) {
      case PdfLayoutMode.horizontal:
        final height =
            pages.fold(0.0, (prev, page) => max(prev, page.size.height)) +
                params.margin * 2;
        final pageLayouts = <Rect>[];
        double x = params.margin;
        for (var page in pages) {
          pageLayouts.add(
            Rect.fromLTWH(
              x,
              (height - page.size.height) / 2, // center vertically
              page.size.width,
              page.size.height,
            ),
          );
          x += page.size.width + params.margin;
        }
        return PdfPageLayout(
          pageLayouts: pageLayouts,
          documentSize: Size(x, height),
        );

      case PdfLayoutMode.facing:
        final width =
            pages.fold(0.0, (prev, page) => max(prev, page.size.width));
        final pageLayouts = <Rect>[];
        final offset = _needCoverPage ? 1 : 0;
        double y = params.margin;

        for (int i = 0; i < pages.length; i++) {
          final page = pages[i];
          final pos = i + offset;
          final isLeft =
              _isRightToLeftReadingOrder ? (pos & 1) == 1 : (pos & 1) == 0;

          final otherSide = (pos ^ 1) - offset;
          final h = 0 <= otherSide && otherSide < pages.length
              ? max(page.size.height, pages[otherSide].size.height)
              : page.size.height;

          pageLayouts.add(
            Rect.fromLTWH(
              isLeft
                  ? width + params.margin - page.size.width
                  : params.margin * 2 + width,
              y + (h - page.size.height) / 2,
              page.size.width,
              page.size.height,
            ),
          );
          if (pos & 1 == 1 || i + 1 == pages.length) {
            y += h + params.margin;
          }
        }
        return PdfPageLayout(
          pageLayouts: pageLayouts,
          documentSize: Size(
            (params.margin + width) * 2 + params.margin,
            y,
          ),
        );

      case PdfLayoutMode.vertical:
      default:
        // For vertical layout, use standard layout
        final pageLayouts = <Rect>[];
        double y = params.margin;
        for (var page in pages) {
          pageLayouts.add(
            Rect.fromLTWH(
              params.margin,
              y,
              page.size.width,
              page.size.height,
            ),
          );
          y += page.size.height + params.margin;
        }
        return PdfPageLayout(
          pageLayouts: pageLayouts,
          documentSize: Size(
            params.margin * 2 +
                pages.fold(0.0, (prev, page) => max(prev, page.size.width)),
            y,
          ),
        );
    }
  }

  void _showFloatingMenuAt(Offset anchor) {
    final screenSize = MediaQuery.of(context).size;
    final bool isInUpperHalf = anchor.dy < (screenSize.height / 2);
    _removeFloatingMenu();
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      context.read<ReaderBloc>().add(ToggleUIVisibility());
    }

    // Calculate positions
    double menuTop;
    final double quickActionsBottom =
        isInUpperHalf ? anchor.dy + 48 : anchor.dy - 48;
    final double quickActionsTop =
        isInUpperHalf ? anchor.dy - 8 : anchor.dy - 88;

    // Position main menu at bottom or top based on selection position
    if (isInUpperHalf) {
      menuTop = screenSize.height * 0.57;
    } else {
      menuTop = -20;
    }

    // Create overlay entry with both quick actions and main menu
    _floatingMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Main menu
          Positioned(
            left: 16,
            right: 16,
            top: menuTop,
            child: Material(
              color: Colors.transparent,
              child: FloatingSelectionMenu(
                selectedText: _selectedText ?? '',
                displayAtTop: !isInUpperHalf,
                onMenuSelected: (menuType, text) {
                  _removeFloatingMenu();
                  switch (menuType) {
                    case SelectionMenuType.askAi:
                    case SelectionMenuType.translate:
                    case SelectionMenuType.dictionary:
                    case SelectionMenuType.wikipedia:
                    case SelectionMenuType.generateImage:
                      showDialog(
                        context: context,
                        barrierColor: Colors.transparent,
                        barrierDismissible: false,
                        builder: (context) => Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (_) {},
                              ),
                            ),
                            FullSelectionMenu(
                              selectedText: text,
                              menuType: menuType,
                              onDismiss: () => Navigator.pop(context),
                              floatingChatKey: _floatingChatKey,
                            ),
                          ],
                        ),
                      );
                      break;
                    default:
                      break;
                  }
                },
                onDismiss: _removeFloatingMenu,
                onExpand: () {
                  _removeFloatingMenu();
                  showDialog(
                    context: context,
                    barrierColor: Colors.transparent,
                    barrierDismissible: false,
                    builder: (context) => Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (_) {},
                          ),
                        ),
                        FullSelectionMenu(
                          selectedText: _selectedText ?? '',
                          menuType: SelectionMenuType.askAi,
                          onDismiss: () => Navigator.pop(context),
                          floatingChatKey: _floatingChatKey,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Quick action buttons near text selection
          Positioned(
            left: max(16, anchor.dx - 120),
            top: isInUpperHalf ? quickActionsTop : quickActionsBottom,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF352A3B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Highlight button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        onTap: () {
                          _removeFloatingMenu();
                          _addCurrentSelectionToMarkers(Colors.yellow);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.highlight,
                                size: 20,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Highlight',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFAA96B6)
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 24,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF4A4A4A)
                          : const Color(0xFFE0E0E0),
                    ),

                    // Audio button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(20),
                        ),
                        onTap: () {
                          // Handle audio functionality
                          _removeFloatingMenu();
                          // Audio playback functionality would go here
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_outlined,
                                size: 20,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Audio',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFAA96B6)
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_floatingMenuEntry!);
  }

  void _removeFloatingMenu() {
    _floatingMenuEntry?.remove();
    _floatingMenuEntry = null;
    _floatingMenuTimer?.cancel();
    _floatingMenuTimer = null;
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

          // Get keyboard information
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final isKeyboardVisible = keyboardHeight > 0;

          Widget pdfViewer = PdfViewer.file(
            file.path,
            controller: _controller,
            initialPageNumber: currentPage,
            params: PdfViewerParams(
              enableTextSelection: true,
              maxScale: 4.0,
              minScale: 0.5,
              onPageChanged: (page) {
                if (mounted && page != null && _lastSliderValue == null) {
                  // Only update if the page actually changed and it's not the initial load
                  if (page != currentPage && _controller.isReady) {
                    context.read<ReaderBloc>().add(JumpToPage(page));
                  }
                }
              },
              layoutPages: _handleLayoutPages,
              onTextSelectionChange: _handleTextSelectionChange,
              viewerOverlayBuilder: (context, size, handleLinkTap) => [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    // Handle link tap first
                    handleLinkTap(details.localPosition);

                    // Only handle page navigation if no side panels are open
                    if (!_showSearchPanel && !(state.showSideNav)) {
                      final tapArea = size.width *
                          0.13; // 13% of screen width for tap zones
                      if (details.localPosition.dx < tapArea) {
                        // Left tap zone - go to previous page
                        if (_layoutMode == PdfLayoutMode.facing) {
                          _controller.goToPage(
                              pageNumber: max(1, currentPage - 2));
                        } else {
                          _controller.goToPage(
                              pageNumber: max(1, currentPage - 1));
                        }
                      } else if (details.localPosition.dx >
                          size.width - tapArea) {
                        // Right tap zone - go to next page
                        if (_layoutMode == PdfLayoutMode.facing) {
                          _controller.goToPage(
                              pageNumber: min(totalPages, currentPage + 2));
                        } else {
                          _controller.goToPage(
                              pageNumber: min(totalPages, currentPage + 1));
                        }
                      } else {
                        // Center area - toggle UI
                        _handleTap();
                      }
                    } else {
                      // If side panels are open, only handle center taps to close them
                      if (details.localPosition.dx >
                          ResponsiveConstants.getSideNavWidth(context)) {
                        _handleTap();
                      }
                    }
                  },
                  // Cover entire viewer area but let events pass through
                  child: IgnorePointer(
                    child: SizedBox(width: size.width, height: size.height),
                  ),
                ),
              ],
              selectableRegionInjector: (context, child) {
                return SelectionArea(
                  onSelectionChanged: (selection) {
                    final selectedText = selection?.plainText ?? '';
                    setState(() {
                      _showAskAiButton = selectedText.isNotEmpty;
                      _selectedText = selectedText;
                    });
                    // If no text is selected, remove any existing overlay
                    if (selectedText.isEmpty) {
                      _removeFloatingMenu();
                    }
                  },
                  child: Listener(
                    onPointerDown: (event) {
                      // Save the pointer down position (global coordinates)
                      _lastPointerDownPosition = event.position;
                    },
                    onPointerUp: (event) {
                      // Use the stored pointer-down position if available
                      final anchor = _lastPointerDownPosition ?? event.position;
                      if (mounted && _selectedText?.isNotEmpty == true) {
                        // Trigger with minimal delay to allow native menu to appear
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted && _selectedText?.isNotEmpty == true) {
                            _showFloatingMenuAt(anchor);
                          }
                        });
                      }
                    },
                    child: child,
                  ),
                );
              },
              pagePaintCallbacks: [
                _textSearcher.pageTextMatchPaintCallback,
                _paintMarkers,
              ],
              onDocumentChanged: (document) async {
                if (document == null) {
                  documentRef.value = null;
                  outline.value = null;
                  _textSelections = null;
                  _markers.clear();
                }
              },
              onViewerReady: (document, controller) async {
                if (mounted) {
                  documentRef.value = controller.documentRef;
                  outline.value = await document.loadOutline();

                  // Ensure we maintain the correct page after initialization
                  if (currentPage > 1) {
                    // Small delay to ensure the viewer is fully ready
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) {
                      _controller.goToPage(pageNumber: currentPage);
                      // Update the ReaderBloc to ensure slider stays in sync
                      context.read<ReaderBloc>().add(JumpToPage(currentPage));
                    }
                  }
                }
              },
              backgroundColor: state.readingMode == ReadingMode.dark
                  ? Colors.black
                  : Colors.white,
            ),
          );

          pdfViewer = ColorFiltered(
            colorFilter: ColorFilter.mode(
              switch (state.readingMode) {
                ReadingMode.light => Colors.white,
                ReadingMode.dark => Colors.white,
                ReadingMode.darkContrast => Colors.white,
                ReadingMode.sepia => const Color(0xFFF4ECD8),
                ReadingMode.twilight => const Color(0xFF4A4A4A),
                ReadingMode.console => const Color.fromARGB(255, 24, 161, 58),
                ReadingMode.birthday => const Color(0xFF9C27B0),
              },
              switch (state.readingMode) {
                ReadingMode.light => BlendMode.dst,
                ReadingMode.dark => BlendMode.difference,
                ReadingMode.darkContrast => BlendMode.difference,
                ReadingMode.sepia => BlendMode.multiply,
                ReadingMode.twilight => BlendMode.difference,
                ReadingMode.console => BlendMode.overlay,
                ReadingMode.birthday => BlendMode.difference,
              },
            ),
            child: pdfViewer,
          );

          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) {
              if (didPop) {
                context.read<ReaderBloc>().add(CloseReader());
                context.read<FileBloc>().add(CloseViewer());
              }
            },
            child: GestureDetector(
              onTapDown: (details) {
                // Check if tap is outside side widgets
                if (_showSearchPanel || (state.showSideNav)) {
                  final sideNavWidth =
                      ResponsiveConstants.getSideNavWidth(context);
                  if (details.globalPosition.dx > sideNavWidth) {
                    // Close side widgets if tap is outside their area
                    if (_showSearchPanel) {
                      _closeSearchPanel();
                    }
                    if (state.showSideNav) {
                      _closeSideNav(context);
                    }
                  }
                }
              },
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    pdfViewer,

                    // Top app bar nav
                    if (showUI)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppBar(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF251B2F).withOpacity(0.95)
                                  : const Color(0xFFFAF9F7).withOpacity(0.95),
                          elevation: 0,
                          toolbarHeight:
                              ResponsiveConstants.getBottomBarHeight(context) -
                                  12.0,
                          leading: IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                              size: ResponsiveConstants.getIconSize(context),
                            ),
                            onPressed: () {
                              context.read<ReaderBloc>().add(CloseReader());
                              context.read<FileBloc>().add(CloseViewer());
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  NavScreen.globalKey.currentState
                                      ?.hideNavBar(false);
                                }
                              });
                            },
                          ),
                          title: Text(
                            path.basename(state.file.path),
                            style: TextStyle(
                              fontSize:
                                  ResponsiveConstants.getBodyFontSize(context),
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          actions: [
                            IconButton(
                              icon: Icon(
                                Icons.search,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                              ),
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                              onPressed: _toggleSearchPanel,
                            ),
                            IconButton(
                              icon: Icon(
                                Symbols.thumbnail_bar,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                                fill: 0.25
                              ),
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                              onPressed: _toggleSideNav,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.settings,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                size: ResponsiveConstants.getIconSize(context),
                              ),
                              padding: EdgeInsets.all(
                                  ResponsiveConstants.isTablet(context)
                                      ? 12
                                      : 8),
                              onPressed: () {
                                showReaderSettingsMenu(
                                  context: context,
                                  filePath: state.file.path,
                                  currentLayoutMode:
                                      convertToReaderLayoutMode(_layoutMode),
                                  onLayoutModeChanged: (mode) {
                                    final currentPage = context
                                            .read<ReaderBloc>()
                                            .state is ReaderLoaded
                                        ? (context.read<ReaderBloc>().state
                                                as ReaderLoaded)
                                            .currentPage
                                        : 1;

                                    Navigator.pop(context); // Close the menu

                                    setState(() {
                                      switch (mode) {
                                        case ReaderLayoutMode.vertical:
                                          _layoutMode = PdfLayoutMode.vertical;
                                          break;
                                        case ReaderLayoutMode.horizontal:
                                          _layoutMode =
                                              PdfLayoutMode.horizontal;
                                          break;
                                        case ReaderLayoutMode.facing:
                                          _layoutMode = PdfLayoutMode.facing;
                                          break;
                                        default:
                                          _layoutMode = PdfLayoutMode.vertical;
                                      }
                                    });

                                    // Ensure we stay on the same page after layout change
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        _controller.goToPage(
                                            pageNumber: currentPage);
                                      }
                                    });
                                  },
                                  showFacingOption: true,
                                );
                              },
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF251B2F).withOpacity(0.95)
                              : const Color(0xFFFAF9F7).withOpacity(0.95),
                          padding: EdgeInsets.fromLTRB(
                            ResponsiveConstants.getContentPadding(context)
                                    .horizontal /
                                2,
                            0,
                            ResponsiveConstants.getContentPadding(context)
                                    .horizontal /
                                2,
                            ResponsiveConstants.getContentPadding(context)
                                    .bottom +
                                10.0,
                          ),
                          height:
                              ResponsiveConstants.getBottomBarHeight(context),
                          child: Row(
                            children: [
                              Text(
                                '$currentPage',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  fontSize: ResponsiveConstants.getBodyFontSize(
                                      context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight:
                                        ResponsiveConstants.isTablet(context)
                                            ? 4
                                            : 2,
                                    activeTrackColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFAA96B6)
                                            : const Color(0xFF9E7B80),
                                    inactiveTrackColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF352A3B)
                                            : const Color(0xFFF8F1F1),
                                    thumbColor: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFAA96B6)
                                        : const Color(0xFF9E7B80),
                                    overlayColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFAA96B6)
                                                .withOpacity(0.12)
                                            : const Color(0xFF9E7B80)
                                                .withOpacity(0.12),
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius:
                                          ResponsiveConstants.isTablet(context)
                                              ? 8
                                              : 6,
                                    ),
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius:
                                          ResponsiveConstants.isTablet(context)
                                              ? 16
                                              : 12,
                                    ),
                                  ),
                                  child: Slider(
                                    value: currentPage.toDouble(),
                                    min: 1,
                                    max: totalPages.toDouble(),
                                    onChangeStart: (value) {
                                      _sliderDwellTimer?.cancel();
                                      _lastSliderValue = value.toInt();
                                      _isSliderInteracting = true;
                                    },
                                    onChanged: (value) {
                                      final intValue = value.toInt();
                                      context
                                          .read<ReaderBloc>()
                                          .add(JumpToPage(intValue));
                                      if (_lastSliderValue != intValue) {
                                        _sliderDwellTimer?.cancel();
                                        _lastSliderValue = intValue;
                                        _sliderDwellTimer = Timer(
                                            const Duration(milliseconds: 550),
                                            () {
                                          if (mounted &&
                                              _lastSliderValue == intValue) {
                                            _controller.goToPage(
                                                pageNumber: intValue);
                                          }
                                        });
                                      }
                                    },
                                    onChangeEnd: (value) {
                                      _sliderDwellTimer?.cancel();
                                      final intValue = value.toInt();
                                      _controller.goToPage(
                                          pageNumber: intValue);
                                      Future.delayed(
                                          const Duration(milliseconds: 1200),
                                          () {
                                        if (mounted) {
                                          _isSliderInteracting = false;
                                          _lastSliderValue = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$totalPages',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  fontSize: ResponsiveConstants.getBodyFontSize(
                                      context),
                                ),
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
                      left: showSideNav
                          ? 0
                          : -ResponsiveConstants.getSideNavWidth(context),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (details.delta.dx < 0) {
                            // Only handle left swipes
                            _closeSideNav(context);
                          }
                        },
                        child: Container(
                          width: ResponsiveConstants.getSideNavWidth(context),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF251B2F).withOpacity(0.98)
                              : const Color(0xFFFAF9F7).withOpacity(0.98),
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        ResponsiveConstants.isTablet(context)
                                            ? 24
                                            : 16,
                                    vertical:
                                        ResponsiveConstants.isTablet(context)
                                            ? 16
                                            : 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _currentTitle,
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFF2F2F7)
                                              : const Color(0xFF1C1C1E),
                                          fontSize: ResponsiveConstants
                                              .getTitleFontSize(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(
                                          minWidth:
                                              ResponsiveConstants.getIconSize(
                                                  context),
                                          minHeight:
                                              ResponsiveConstants.getIconSize(
                                                  context),
                                        ),
                                        icon: Icon(
                                          Icons.close,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF8E8E93)
                                              : const Color(0xFF6E6E73),
                                          size: ResponsiveConstants.getIconSize(
                                              context),
                                        ),
                                        onPressed: () {
                                          context
                                              .read<ReaderBloc>()
                                              .add(ToggleSideNav());
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF2C2C2E)
                                            : const Color(0xFFF8F1F1),
                                      ),
                                    ),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    tabs: const [
                                      Tab(text: 'Chapters'),
                                      Tab(text: 'Bookmarks'),
                                      Tab(text: 'Pages'),
                                    ],
                                    labelColor: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFAA96B6)
                                        : const Color(0xFF9E7B80),
                                    unselectedLabelColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF8E8E93)
                                            : const Color(0xFF6E6E73),
                                    indicatorColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFAA96B6)
                                            : const Color(0xFF9E7B80),
                                    indicatorWeight: 2,
                                    labelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    unselectedLabelStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF352A3B)
                                            .withOpacity(0.5)
                                        : const Color(0xFFF8F1F1)
                                            .withOpacity(0.5),
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        ValueListenableBuilder(
                                          valueListenable: outline,
                                          builder: (context, outline, child) =>
                                              OutlineView(
                                            outline: outline,
                                            controller: _controller,
                                          ),
                                        ),
                                        MarkersView(
                                          markers: _markers.values
                                              .expand((e) => e)
                                              .toList(),
                                          onTap: (marker) {
                                            final rect = _controller
                                                .calcRectForRectInsidePage(
                                              pageNumber: marker
                                                  .ranges.pageText.pageNumber,
                                              rect: marker.ranges.bounds,
                                            );
                                            _controller.ensureVisible(rect);
                                            context
                                                .read<ReaderBloc>()
                                                .add(ToggleSideNav());
                                          },
                                          onDeleteTap: (marker) =>
                                              _deleteMarker(marker),
                                        ),
                                        ValueListenableBuilder(
                                          valueListenable: documentRef,
                                          builder: (context, docRef, child) =>
                                              ThumbnailsView(
                                            documentRef: docRef,
                                            controller: _controller,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Search panel
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      top: 0,
                      bottom: 0,
                      left: _showSearchPanel
                          ? 0
                          : -ResponsiveConstants.getSideNavWidth(context),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (details.delta.dx < 0) {
                            // Only handle left swipes
                            _closeSearchPanel();
                          }
                        },
                        child: SizedBox(
                          width: ResponsiveConstants.getSideNavWidth(context),
                          child: _showSearchPanel
                              ? TextSearchView(
                                  key: _searchViewKey,
                                  textSearcher: _textSearcher,
                                  onClose: _closeSearchPanel,
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ),

                    // Floating chat widget with keyboard info
                    FloatingChatWidget(
                      character: _characterService.getSelectedCharacter() ??
                          AiCharacter(
                            name: 'Amelia',
                            avatarImagePath:
                                'assets/images/ai_characters/amelia.png',
                            personality: 'A friendly and helpful AI assistant.',
                            summary:
                                'Amelia is a friendly AI assistant who helps readers understand and engage with their books.',
                            scenario:
                                'You are reading with Amelia, who is eager to help you understand and enjoy your book.',
                            greetingMessage:
                                'Hello! I\'m Amelia. How can I help you with your reading today?',
                            exampleMessages: [
                              'Can you explain this passage?',
                              'What are your thoughts on this chapter?',
                              'Help me understand the main themes.'
                            ],
                            characterVersion: '1',
                            tags: ['Default', 'Reading Assistant'],
                            creator: 'ReadLeaf',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                      onSendMessage: _handleChatMessage,
                      bookId: file.path,
                      bookTitle: path.basename(file.path),
                      keyboardHeight: keyboardHeight,
                      isKeyboardVisible: isKeyboardVisible,
                      key: _floatingChatKey,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Center(child: Text(state.toString())),
        );
      },
    );
  }
}
