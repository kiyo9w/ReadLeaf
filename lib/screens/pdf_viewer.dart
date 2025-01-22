import 'dart:io';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/widgets/text_search_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:migrated/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:migrated/widgets/CompanionChat/floating_chat_widget.dart';
import 'package:migrated/models/chat_message.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/screens/character_screen.dart';
import 'package:migrated/utils/utils.dart';
import 'package:migrated/widgets/pdf_viewer/markers_view.dart';
import 'package:migrated/widgets/pdf_viewer/outline_view.dart';
import 'package:migrated/widgets/pdf_viewer/thumbnails_view.dart';

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

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
  bool _showSearchPanel = false;
  bool _isZoomedIn = false;
  bool _showAskAiButton = false;
  bool _isLoadingAiResponse = false;
  String? _selectedText;
  double _scaleFactor = 1.0;
  double _baseScaleFactor = 1.0;
  final _markers = <int, List<Marker>>{};
  List<PdfTextRanges>? _textSelections;
  final outline = ValueNotifier<List<PdfOutlineNode>?>(null);
  final documentRef = ValueNotifier<PdfDocumentRef?>(null);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textSearcher.removeListener(_update);
    _textSearcher.dispose();
    outline.dispose();
    documentRef.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
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
    context.read<ReaderBloc>().add(ToggleUIVisibility());
    if (_showSearchPanel) _closeSearchPanel();
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      if (state.showSideNav) _closeSideNav(context);
    }
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
        _showAskAiButton = selectedText.isNotEmpty;
        _textSelections = selections;
      });
    } else {
      setState(() {
        _selectedText = null;
        _showAskAiButton = false;
        _textSelections = null;
      });
    }
  }

  void _addCurrentSelectionToMarkers(Color color) {
    if (_controller.isReady && _textSelections != null) {
      for (final selectedText in _textSelections!) {
        _markers
            .putIfAbsent(selectedText.pageNumber, () => [])
            .add(Marker(color, selectedText));
      }
      setState(() {});
    }
  }

  void _paintMarkers(Canvas canvas, Rect pageRect, PdfPage page) {
    final markers = _markers[page.pageNumber];
    if (markers == null) {
      return;
    }
    for (final marker in markers) {
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

  void _handleChatMessage(String? message, {String? selectedText}) async {
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
      );

      if (!mounted) return;

      if (_floatingChatKey.currentState != null) {
        _floatingChatKey.currentState!.addAiResponse(response);
      }
    } catch (e) {
      if (!mounted) return;
      Utils.showErrorSnackBar(context, 'Failed to get AI response');
    }
  }

  void _handleAskAi() async {
    if (_selectedText == null || _selectedText!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select some text to ask AI.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String selectedTextCopy = _selectedText!;

    if (selectedTextCopy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selected text appears to be empty. Please try selecting again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool isLoading = false;
    String? customPrompt;
    final promptController = TextEditingController();

    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the document to load completely.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bookTitle = path.basename(state.file.path);
    final currentPage = state.currentPage;
    final totalPages = state.totalPages;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return GestureDetector(
            onTap: () => Navigator.pop(dialogContext),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap:
                    () {}, // Prevent tap from propagating to outer GestureDetector
                child: Dialog(
                  alignment: Alignment.bottomCenter,
                  insetPadding: EdgeInsets.zero,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF251B2F)
                          : Colors.white,
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                        maxWidth: 500,
                      ),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final keyboardVisible =
                              MediaQuery.of(context).viewInsets.bottom > 0;
                          final availableHeight = constraints.maxHeight;
                          final contentHeight = keyboardVisible
                              ? availableHeight - 180
                              : availableHeight;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header - Always visible
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Ask AI Assistant',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Scrollable content
                              Flexible(
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Book info - Minimal design
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.description_outlined,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              bookTitle.length > 30
                                                  ? '${bookTitle.substring(0, 27)}...'
                                                  : bookTitle,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF352A3B)
                                                      .withOpacity(0.5)
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$currentPage/$totalPages',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Selected text section
                                      Container(
                                        height: keyboardVisible
                                            ? 60
                                            : contentHeight * 0.3,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF352A3B)
                                                  .withOpacity(0.3)
                                              : Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF352A3B)
                                                    : Colors.grey[200]!,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.text_fields,
                                                          size: 18,
                                                          color:
                                                              Colors.grey[600]),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'Selected Text',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (!keyboardVisible)
                                                    Text(
                                                      '${selectedTextCopy.length} characters',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (!keyboardVisible)
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          12, 0, 12, 12),
                                                  child: SelectableText(
                                                    selectedTextCopy,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontSize: 14,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Custom instructions section
                                      const Text(
                                        'Custom Instructions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: promptController,
                                        maxLines: keyboardVisible ? 2 : 3,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Example: Explain this in simple terms\nOr: Translate this to French',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[400]),
                                          filled: true,
                                          fillColor:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF352A3B)
                                                      .withOpacity(0.3)
                                                  : Colors.grey[50],
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF352A3B)
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF352A3B)
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFAA96B6)
                                                  : Theme.of(context)
                                                      .primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          customPrompt =
                                              value.isNotEmpty ? value : null;
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Action buttons
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              foregroundColor: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF8E8E93)
                                                  : Colors.grey[600],
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (selectedTextCopy.isEmpty)
                                                return;

                                              setDialogState(
                                                  () => isLoading = true);
                                              Navigator.pop(dialogContext);
                                              _floatingChatKey.currentState
                                                  ?.showChat();

                                              await Future.delayed(
                                                  const Duration(
                                                      milliseconds: 100));

                                              if (!mounted) return;

                                              if (selectedTextCopy.isNotEmpty) {
                                                _floatingChatKey.currentState!
                                                    .addUserMessage(
                                                        'Imported Text: """$selectedTextCopy"""');

                                                if (customPrompt != null &&
                                                    customPrompt!.isNotEmpty) {
                                                  _floatingChatKey.currentState!
                                                      .addUserMessage(
                                                          customPrompt!);
                                                }
                                              }

                                              _handleChatMessage(
                                                customPrompt,
                                                selectedText: selectedTextCopy,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              backgroundColor: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFAA96B6)
                                                  : Theme.of(context)
                                                      .primaryColor,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.chat_bubble_outline,
                                                    size: 18,
                                                    color: Colors.white),
                                                const SizedBox(width: 8),
                                                const Text('Ask AI'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
              onPageChanged: (page) {
                if (mounted && page != null) {
                  context.read<ReaderBloc>().add(JumpToPage(page));
                }
              },
              onTextSelectionChange: _handleTextSelectionChange,
              selectableRegionInjector: (context, child) {
                return SelectionArea(
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showAskAiButton =
                          selection?.plainText?.isNotEmpty == true;
                      _selectedText = selection?.plainText;
                    });
                  },
                  child: child,
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
                documentRef.value = controller.documentRef;
                outline.value = await document.loadOutline();
              },
              linkHandlerParams: PdfLinkHandlerParams(
                onLinkTap: _handleLink,
                linkColor: Colors.blue.withOpacity(0.15),
                customPainter: (canvas, pageRect, page, links) {
                  final paint = Paint()
                    ..color = Colors.blue.withOpacity(0.1)
                    ..style = PaintingStyle.fill;
                  for (final link in links) {
                    for (final rect in link.rects) {
                      canvas.drawRRect(
                        RRect.fromRectAndRadius(
                          rect.toRectInPageRect(
                            page: page,
                            pageRect: pageRect,
                          ),
                          const Radius.circular(4),
                        ),
                        paint,
                      );
                    }
                  }
                },
              ),
              viewerOverlayBuilder: (context, size, handleLinkTap) => [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    handleLinkTap(details.localPosition);
                    _handleTap();
                  },
                  onDoubleTapDown: (details) {
                    _handleDoubleTap(details);
                  },
                  child: IgnorePointer(
                    child: SizedBox(width: size.width, height: size.height),
                  ),
                ),
              ],
            ),
          );

          return WillPopScope(
            onWillPop: () async {
              context.read<ReaderBloc>().add(CloseReader());
              context.read<FileBloc>().add(CloseViewer());
              return true;
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false, // Prevent scaffold from resizing
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
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                          ),
                          onPressed: () {
                            context.read<ReaderBloc>().add(CloseReader());
                            context.read<FileBloc>().add(CloseViewer());
                            Navigator.pop(context);
                          },
                        ),
                        title: Text(
                          path.basename(state.file.path),
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                            ),
                            onPressed: _toggleSearchPanel,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                            ),
                            onPressed: () {
                              context.read<ReaderBloc>().add(ToggleSideNav());
                            },
                          ),
                          PopupMenuButton<String>(
                            elevation: 8,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF352A3B)
                                    : const Color(0xFFF8F1F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            icon: Icon(
                              Icons.more_vert,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                            ),
                            position: PopupMenuPosition.under,
                            onSelected: (val) {
                              if (val == 'dark_mode') {
                                context
                                    .read<ReaderBloc>()
                                    .add(ToggleReadingMode());
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'dark_mode',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.dark_mode,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Dark mode',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'move_trash',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Move to trash',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.share_outlined,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Share file',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ],
                                ),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF251B2F).withOpacity(0.95)
                            : const Color(0xFFFAF9F7).withOpacity(0.95),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        height: 65,
                        child: Row(
                          children: [
                            Text(
                              '$currentPage',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
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
                                  overlayColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFAA96B6)
                                          .withOpacity(0.12)
                                      : const Color(0xFF9E7B80)
                                          .withOpacity(0.12),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                ),
                                child: Slider(
                                  value: currentPage.toDouble(),
                                  min: 1,
                                  max: totalPages.toDouble(),
                                  onChanged: (value) {
                                    final page = value.toInt();
                                    _controller.goToPage(pageNumber: page);
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
                                fontSize: 14,
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
                    left: showSideNav ? 0 : -300,
                    child: Container(
                      width: 300,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF251B2F).withOpacity(0.98)
                          : const Color(0xFFFAF9F7).withOpacity(0.98),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    icon: Icon(
                                      Icons.close,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF8E8E93)
                                          : const Color(0xFF6E6E73),
                                      size: 20,
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
                                indicatorColor: Theme.of(context).brightness ==
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
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF352A3B).withOpacity(0.5)
                                    : const Color(0xFFF8F1F1).withOpacity(0.5),
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
                                          pageNumber:
                                              marker.ranges.pageText.pageNumber,
                                          rect: marker.ranges.bounds,
                                        );
                                        _controller.ensureVisible(rect);
                                        context
                                            .read<ReaderBloc>()
                                            .add(ToggleSideNav());
                                      },
                                      onDeleteTap: (marker) {
                                        _markers[marker.ranges.pageNumber]!
                                            .remove(marker);
                                        setState(() {});
                                      },
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

                  // Highlight controls
                  if (_showAskAiButton && _selectedText?.isNotEmpty == true)
                    Positioned(
                      bottom: state.showUI ? 80 : 16,
                      right: 16,
                      child: Row(
                        children: [
                          FloatingActionButton(
                            heroTag: 'highlight_yellow',
                            mini: true,
                            backgroundColor: Colors.yellow.withOpacity(0.9),
                            child: const Icon(Icons.brush,
                                color: Colors.black87, size: 20),
                            onPressed: () =>
                                _addCurrentSelectionToMarkers(Colors.yellow),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton(
                            heroTag: 'highlight_red',
                            mini: true,
                            backgroundColor: Colors.red.withOpacity(0.9),
                            child: const Icon(Icons.brush,
                                color: Colors.white, size: 20),
                            onPressed: () =>
                                _addCurrentSelectionToMarkers(Colors.red),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.extended(
                            onPressed: _handleAskAi,
                            icon: const Icon(Icons.chat, color: Colors.white),
                            label: const Text('Ask AI',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ),

                  // Floating chat widget with keyboard info
                  FloatingChatWidget(
                    character: _characterService.getSelectedCharacter() ??
                        AiCharacter(
                          name: 'Amelia',
                          imagePath: 'assets/images/ai_characters/amelia.png',
                          personality: 'A friendly and helpful AI assistant.',
                          trait: 'Friendly and helpful',
                          categories: ['Default'],
                          promptTemplate:
                              'You are Amelia, a friendly AI assistant.\n\nCURRENT TASK:\n{USER_PROMPT}',
                          taskPrompts: {
                            'greeting':
                                'Hello! I\'m Amelia. How can I help you today?',
                            'analyze_text':
                                'I\'ll help you understand this text.',
                            'encouragement':
                                'You\'re doing great! Keep reading!',
                          },
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
          );
        }

        return Scaffold(
          body: Center(child: Text('${state.toString()}')),
        );
      },
    );
  }
}
