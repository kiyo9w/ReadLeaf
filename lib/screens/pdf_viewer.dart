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

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final _controller = PdfViewerController();
  late final _textSearcher = PdfTextSearcher(_controller)..addListener(_update);
  late final _geminiService = GetIt.I<GeminiService>();
  late final _characterService = GetIt.I<AiCharacterService>();
  final GlobalKey<FloatingChatWidgetState> _floatingChatKey = GlobalKey();
  bool _showSearchPanel = false;
  bool _isZoomedIn = false;
  bool _showAskAiButton = false;
  bool _isLoadingAiResponse = false;
  String? _selectedText;
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
      });
    } else {
      setState(() {
        _selectedText = null;
        _showAskAiButton = false;
      });
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Get screen metrics
          final screenSize = MediaQuery.of(context).size;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final isKeyboardVisible = keyboardHeight > 0;
          final bottomPadding = MediaQuery.of(context).padding.bottom;

          // Calculate available height for dialog
          final availableHeight = screenSize.height -
              (isKeyboardVisible ? keyboardHeight : 0) -
              bottomPadding -
              32; // Account for minimal padding

          return Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.only(
                bottom: isKeyboardVisible ? keyboardHeight : 0,
              ),
              child: Dialog(
                alignment: Alignment.bottomCenter,
                insetPadding: EdgeInsets.zero,
                child: Container(
                  width: screenSize.width,
                  constraints: BoxConstraints(
                    maxHeight: min(availableHeight, 600),
                    maxWidth: 500,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: isLoading
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Asking AI...'),
                                      ],
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header
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

                                      // Book info card
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    bookTitle.length > 40
                                                        ? '${bookTitle.substring(0, 37)}...'
                                                        : bookTitle,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'Page $currentPage of $totalPages',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Selected text section with dynamic height
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        height: isKeyboardVisible ? 80 : 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[200]!),
                                        ),
                                        child: Column(
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
                                            Expanded(
                                              child: SingleChildScrollView(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        12, 0, 12, 12),
                                                child: SelectableText(
                                                  selectedTextCopy,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),

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
                                        maxLines: isKeyboardVisible ? 2 : 3,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Example: Explain this in simple terms\nOr: Translate this to French',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[400]),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey[300]!),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
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
                                      // const SizedBox(height: 24),

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
                      ),
                    ],
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
              ],
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
                    //   // Cancel the single tap handler when double tap is detected
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        height: 65, // Increased height
                        child: Row(
                          children: [
                            Text(
                              '$currentPage',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                ),
                                child: Slider(
                                  value: currentPage.toDouble(),
                                  min: 1,
                                  max: totalPages.toDouble(),
                                  activeColor: Colors.pinkAccent,
                                  inactiveColor: Colors.white54,
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
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
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
                                  context
                                      .read<ReaderBloc>()
                                      .add(ToggleSideNav());
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

                  if (_showAskAiButton && _selectedText?.isNotEmpty == true)
                    Positioned(
                      bottom: state.showUI
                          ? 80
                          : 16, // Position above the bottom nav when it's shown
                      right: 16,
                      child: FloatingActionButton.extended(
                        onPressed: _handleAskAi,
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: const Text('Ask AI',
                            style: TextStyle(color: Colors.white)),
                        backgroundColor: Theme.of(context).primaryColor,
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
