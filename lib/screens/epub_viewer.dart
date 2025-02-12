import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:read_leaf/screens/nav_screen.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/widgets/CompanionChat/floating_chat_widget.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/models/ai_character.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:read_leaf/services/thumbnail_service.dart';
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/providers/theme_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

enum EpubLayoutMode { vertical, horizontal, facing }

class PageContent {
  final String content;
  final int chapterIndex;
  final int pageNumberInChapter;
  final String chapterTitle;

  PageContent({
    required this.content,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    required this.chapterTitle,
  });
}

class EPUBViewerScreen extends StatefulWidget {
  const EPUBViewerScreen({super.key});

  @override
  State<EPUBViewerScreen> createState() => _EPUBViewerScreenState();
}

class _EPUBViewerScreenState extends State<EPUBViewerScreen> {
  late final _geminiService = GetIt.I<GeminiService>();
  late final _characterService = GetIt.I<AiCharacterService>();
  late final _metadataRepository = GetIt.I<BookMetadataRepository>();
  late final _thumbnailService = GetIt.I<ThumbnailService>();
  final GlobalKey<FloatingChatWidgetState> _floatingChatKey = GlobalKey();
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  EpubBook? _epubBook;
  List<EpubChapter> _flatChapters = [];
  int _currentChapterIndex = 0;
  String? _selectedText;
  bool _isLoading = true;
  bool _showChapters = false;
  ImageProvider? _coverImage;
  BookMetadata? _metadata;
  bool _isDisposed = false;
  EpubLayoutMode _layoutMode = EpubLayoutMode.vertical;
  bool _isRightToLeftReadingOrder = false;
  Timer? _sliderDwellTimer;
  int? _lastSliderValue;
  bool _isSliderInteracting = false;
  Map<int, String> _chapterContentCache = {};
  Map<int, List<PageContent>> _chapterPagesCache = {};
  int _totalPages = 0;
  int _currentPage = 0;
  static const int _wordsPerPage = 500; // Approximate words per page

  @override
  void initState() {
    super.initState();
    _initializeReader();
  }

  Future<void> _initializeReader() async {
    await Future.delayed(Duration.zero); // Wait for widget to be mounted
    if (!mounted) return;

    NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    _positionsListener.itemPositions.addListener(_onScroll);
    await _loadEpub();
  }

  @override
  void dispose() {
    _cleanupCache();
    _isDisposed = true;
    _positionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isDisposed) return;

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final firstIndex = positions.first.index;
    if (firstIndex != _currentChapterIndex) {
      if (!_isDisposed) {
        setState(() {
          _currentChapterIndex = firstIndex;
          _loadSurroundingChapters(firstIndex);
        });
      }

      // Update the current page in the bloc and metadata
      if (mounted) {
        final page = _calculateCurrentPage();
        context.read<ReaderBloc>().add(JumpToPage(page));
        _updateMetadata(page);
      }
    }
  }

  int _calculateCurrentPage() {
    int page = 1;
    for (var i = 0; i < _currentChapterIndex; i++) {
      page += _chapterPagesCache[i]?.length ?? 0;
    }
    return page;
  }

  Future<void> _jumpToPage(int targetPage) async {
    int currentPage = 0;
    int targetChapter = 0;

    for (var i = 0; i < _flatChapters.length; i++) {
      final chapterPages = _chapterPagesCache[i]?.length ?? 0;
      if (currentPage + chapterPages >= targetPage) {
        targetChapter = i;
        break;
      }
      currentPage += chapterPages;
    }

    // Load the target chapter and surrounding chapters
    await _loadSurroundingChapters(targetChapter);

    if (_scrollController.isAttached && mounted) {
      await _scrollController.scrollTo(
        index: targetChapter,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<void> _updateMetadata(int currentPage) async {
    if (_metadata == null || _isDisposed) return;

    final updatedMetadata = _metadata!.copyWith(
      lastOpenedPage: currentPage,
      lastReadTime: DateTime.now(),
      readingProgress: currentPage / _metadata!.totalPages,
    );

    await _metadataRepository.saveMetadata(updatedMetadata);
    if (!_isDisposed) {
      setState(() {
        _metadata = updatedMetadata;
      });
    }
  }

  Future<void> _loadEpub() async {
    if (_isDisposed) return;

    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

    try {
      final bytes = await state.file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      // Flatten chapters for easier navigation
      final chapters = _flattenChapters(book.Chapters ?? []);

      // Pre-cache initial chapters
      final initialChapterIndex = 0;
      await Future.wait([
        _preloadChapter(initialChapterIndex),
        _preloadChapter(initialChapterIndex + 1),
      ]);

      // Get or create metadata
      BookMetadata? metadata = _metadataRepository.getMetadata(state.file.path);
      if (metadata == null) {
        metadata = BookMetadata(
          filePath: state.file.path,
          title: book.Title ?? path.basename(state.file.path),
          author: book.Author,
          totalPages: chapters.length,
          lastReadTime: DateTime.now(),
          fileType: 'epub',
        );
        await _metadataRepository.saveMetadata(metadata);
      }

      // Get cover image using thumbnail service
      final coverImage =
          await _thumbnailService.getFileThumbnail(state.file.path);

      if (!_isDisposed) {
        setState(() {
          _epubBook = book;
          _flatChapters = chapters;
          _metadata = metadata;
          _coverImage = coverImage;
          _currentChapterIndex = metadata?.lastOpenedPage != null
              ? metadata!.lastOpenedPage - 1
              : 0;
          _isLoading = false;
        });

        // Load the initial chapter's pages
        await _splitChapterIntoPages(_currentChapterIndex);

        // Start preloading surrounding chapters
        _loadSurroundingChapters(_currentChapterIndex);
      }

      // Scroll to last read position
      if (_currentChapterIndex > 0 &&
          _scrollController.isAttached &&
          !_isDisposed) {
        await _scrollController.scrollTo(
          index: _currentChapterIndex,
          duration: const Duration(milliseconds: 300),
        );
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        Utils.showErrorSnackBar(context, 'Error loading EPUB: $e');
      }
    }
  }

  Future<void> _preloadChapter(int index) async {
    if (index < 0 || index >= _flatChapters.length) return;
    if (_chapterContentCache.containsKey(index)) return;

    try {
      final chapter = _flatChapters[index];
      _chapterContentCache[index] = chapter.HtmlContent ?? '';
    } catch (e) {
      print('Error preloading chapter $index: $e');
    }
  }

  void _cleanupCache() {
    // Keep only nearby chapters in memory
    final chaptersToKeep = <int>{
      _currentChapterIndex - 1,
      _currentChapterIndex,
      _currentChapterIndex + 1,
    };

    _chapterContentCache
        .removeWhere((key, value) => !chaptersToKeep.contains(key));
    _chapterPagesCache
        .removeWhere((key, value) => !chaptersToKeep.contains(key));
  }

  Future<bool> _handleBackPress() async {
    try {
      // Save current progress before popping
      if (_metadata != null) {
        await _updateMetadata(_currentChapterIndex + 1);
      }
      if (mounted) {
        context.read<ReaderBloc>().add(CloseReader());
        context.read<FileBloc>().add(CloseViewer());
      }
      return true;
    } catch (e) {
      print('Error handling back press: $e');
      return false;
    }
  }

  List<EpubChapter> _flattenChapters(List<EpubChapter> chapters,
      [int level = 0]) {
    List<EpubChapter> result = [];
    for (var chapter in chapters) {
      result.add(chapter);
      if (chapter.SubChapters?.isNotEmpty == true) {
        result.addAll(_flattenChapters(chapter.SubChapters!, level + 1));
      }
    }
    return result;
  }

  void _handleChatMessage(String? message, {String? selectedText}) async {
    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

    final bookTitle = _epubBook?.Title ?? path.basename(state.file.path);
    final currentPage = _currentChapterIndex + 1;
    final totalPages = _flatChapters.length;

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

  void _handleLayoutChange(EpubLayoutMode mode) {
    setState(() {
      _layoutMode = mode;
    });
    // Re-render the current chapter with new layout
    if (_scrollController.isAttached && mounted) {
      _scrollController.jumpTo(index: _currentChapterIndex);
    }
  }

  Future<void> _splitChapterIntoPages(int chapterIndex) async {
    if (_chapterPagesCache.containsKey(chapterIndex)) return;

    final chapter = _flatChapters[chapterIndex];
    final content = _chapterContentCache[chapterIndex] ?? '';

    // Split content into words
    final words = content.split(RegExp(r'\s+'));
    final pages = <PageContent>[];

    for (var i = 0; i < words.length; i += _wordsPerPage) {
      final pageWords = words.skip(i).take(_wordsPerPage).join(' ');
      pages.add(PageContent(
        content: pageWords,
        chapterIndex: chapterIndex,
        pageNumberInChapter: pages.length + 1,
        chapterTitle: chapter.Title ?? 'Chapter ${chapterIndex + 1}',
      ));
    }

    _chapterPagesCache[chapterIndex] = pages;

    if (!_isDisposed) {
      setState(() {
        _totalPages = _calculateTotalPages();
      });
    }
  }

  int _calculateTotalPages() {
    return _chapterPagesCache.values
        .fold(0, (sum, pages) => sum + pages.length);
  }

  Future<void> _loadSurroundingChapters(int currentChapterIndex) async {
    final chaptersToLoad = <int>{
      currentChapterIndex - 1,
      currentChapterIndex,
      currentChapterIndex + 1,
    };

    for (final index in chaptersToLoad) {
      if (index >= 0 && index < _flatChapters.length) {
        await _splitChapterIntoPages(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {},
      builder: (context, state) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_epubBook == null) {
          return const Scaffold(
            body: Center(child: Text('Failed to load EPUB')),
          );
        }

        if (state is! ReaderLoaded) {
          return const Scaffold(
            body: Center(child: Text('Reader not loaded')),
          );
        }

        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        final showUI = state.showUI;

        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              try {
                // Save current progress before popping
                if (_metadata != null) {
                  await _updateMetadata(_currentChapterIndex + 1);
                }
                if (mounted) {
                  context.read<ReaderBloc>().add(CloseReader());
                  context.read<FileBloc>().add(CloseViewer());
                }
              } catch (e) {
                print('Error handling pop: $e');
              }
            }
          },
          child: GestureDetector(
            onTapDown: (details) {
              // Check if tap is outside side widgets
              if (_showChapters) {
                final sideNavWidth =
                    ResponsiveConstants.getSideNavWidth(context);
                if (details.globalPosition.dx > sideNavWidth) {
                  // Close side widgets if tap is outside their area
                  setState(() {
                    _showChapters = false;
                  });
                }
              }
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: Stack(
                children: [
                  // Main content
                  ScrollablePositionedList.builder(
                    itemCount: _flatChapters.length,
                    itemBuilder: (context, index) =>
                        _buildChapter(_flatChapters[index]),
                    itemScrollController: _scrollController,
                    itemPositionsListener: _positionsListener,
                  ),

                  // Top app bar
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
                            ResponsiveConstants.getBottomBarHeight(context),
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF2F2F7)
                                    : const Color(0xFF1C1C1E),
                            size: ResponsiveConstants.getIconSize(context),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        title: Text(
                          _epubBook?.Title ?? path.basename(state.file.path),
                          style: TextStyle(
                            fontSize:
                                ResponsiveConstants.getBodyFontSize(context),
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
                              size: ResponsiveConstants.getIconSize(context),
                            ),
                            onPressed: () {
                              // TODO: Implement search functionality for EPUB
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Search coming soon for EPUB files'),
                                ),
                              );
                            },
                            padding: EdgeInsets.all(
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFF2F2F7)
                                  : const Color(0xFF1C1C1E),
                              size: ResponsiveConstants.getIconSize(context),
                            ),
                            onPressed: () {
                              setState(() {
                                _showChapters = !_showChapters;
                              });
                            },
                            padding: EdgeInsets.all(
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
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
                              size: ResponsiveConstants.getIconSize(context),
                            ),
                            padding: EdgeInsets.all(
                                ResponsiveConstants.isTablet(context) ? 12 : 8),
                            position: PopupMenuPosition.under,
                            onSelected: (val) async {
                              switch (val) {
                                case 'layout_mode':
                                  final RenderBox button =
                                      context.findRenderObject() as RenderBox;
                                  final RenderBox overlay =
                                      Navigator.of(context)
                                          .overlay!
                                          .context
                                          .findRenderObject() as RenderBox;
                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                    Rect.fromPoints(
                                      button.localToGlobal(Offset.zero),
                                      button.localToGlobal(
                                          button.size.bottomRight(Offset.zero)),
                                    ),
                                    Offset.zero & overlay.size,
                                  );

                                  showMenu<EpubLayoutMode>(
                                    context: context,
                                    position: position,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF352A3B)
                                        : const Color(0xFFF8F1F1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        value: EpubLayoutMode.vertical,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.vertical_distribute,
                                              color: _layoutMode ==
                                                      EpubLayoutMode.vertical
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : null,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text('Vertical Scroll',
                                                style: TextStyle(
                                                  color: _layoutMode ==
                                                          EpubLayoutMode
                                                              .vertical
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                      : null,
                                                )),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: EpubLayoutMode.horizontal,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.horizontal_distribute,
                                              color: _layoutMode ==
                                                      EpubLayoutMode.horizontal
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : null,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text('Horizontal Scroll',
                                                style: TextStyle(
                                                  color: _layoutMode ==
                                                          EpubLayoutMode
                                                              .horizontal
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                      : null,
                                                )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ).then((EpubLayoutMode? mode) {
                                    if (mode != null && mounted) {
                                      _handleLayoutChange(mode);
                                    }
                                  });
                                  break;
                                case 'reading_mode':
                                  final readingMode =
                                      await showMenu<ReadingMode>(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      MediaQuery.of(context).size.width - 200,
                                      kToolbarHeight + 20,
                                      MediaQuery.of(context).size.width - 10,
                                      kToolbarHeight + 100,
                                    ),
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF352A3B)
                                        : const Color(0xFFF8F1F1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        value: ReadingMode.light,
                                        child: Text('Light',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E))),
                                      ),
                                      PopupMenuItem(
                                        value: ReadingMode.dark,
                                        child: Text('Dark',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E))),
                                      ),
                                      PopupMenuItem(
                                        value: ReadingMode.sepia,
                                        child: Text('Sepia',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFFF2F2F7)
                                                    : const Color(0xFF1C1C1E))),
                                      ),
                                    ],
                                  );
                                  if (readingMode != null && mounted) {
                                    context
                                        .read<ReaderBloc>()
                                        .add(setReadingMode(readingMode));
                                  }
                                  break;
                                case 'move_trash':
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete File'),
                                      content: const Text(
                                          'Are you sure you want to delete this file? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldDelete == true && mounted) {
                                    try {
                                      final file = File(state.file.path);
                                      if (await file.exists()) {
                                        await file.delete();
                                        if (mounted) {
                                          context
                                              .read<FileBloc>()
                                              .add(RemoveFile(state.file.path));
                                          context
                                              .read<ReaderBloc>()
                                              .add(CloseReader());
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Error deleting file: $e')),
                                        );
                                      }
                                    }
                                  }
                                  break;
                                case 'share':
                                  try {
                                    final file = File(state.file.path);
                                    if (await file.exists()) {
                                      await Share.share(
                                        state.file.path,
                                        subject: path.basename(state.file.path),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error sharing file: $e')),
                                      );
                                    }
                                  }
                                  break;
                                case 'toggle_star':
                                  context
                                      .read<FileBloc>()
                                      .add(ToggleStarred(state.file.path));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Updated starred status'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  break;
                                case 'mark_as_read':
                                  context
                                      .read<FileBloc>()
                                      .add(ViewFile(state.file.path));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Marked as read'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'layout_mode',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.view_agenda_outlined,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Page Layout',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_right,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'reading_mode',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Reading Mode',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFF2F2F7)
                                            : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_right,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
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
                              PopupMenuItem(
                                value: 'toggle_star',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_outline,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Toggle star',
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
                                value: 'mark_as_read',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFF2F2F7)
                                          : const Color(0xFF1C1C1E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Mark as read',
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

                  // Side navigation (Chapters)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: 0,
                    bottom: 0,
                    left: _showChapters
                        ? 0
                        : -ResponsiveConstants.getSideNavWidth(context),
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (details.delta.dx < 0) {
                          // Only handle left swipes
                          setState(() {
                            _showChapters = false;
                          });
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
                                      'Chapters',
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
                                        setState(() {
                                          _showChapters = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _flatChapters.length,
                                  itemBuilder: (context, index) {
                                    final chapter = _flatChapters[index];
                                    return ListTile(
                                      title: Text(
                                        chapter.Title ?? 'Chapter ${index + 1}',
                                        style: TextStyle(
                                          color: _currentChapterIndex == index
                                              ? Theme.of(context).primaryColor
                                              : Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFF2F2F7)
                                                  : const Color(0xFF1C1C1E),
                                          fontSize: ResponsiveConstants
                                              .getBodyFontSize(context),
                                        ),
                                      ),
                                      onTap: () {
                                        _scrollController.scrollTo(
                                          index: index,
                                          duration:
                                              const Duration(milliseconds: 300),
                                        );
                                        setState(() {
                                          _showChapters = false;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating chat widget
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
                    bookId: state.file.path,
                    bookTitle:
                        _epubBook?.Title ?? path.basename(state.file.path),
                    keyboardHeight: keyboardHeight,
                    isKeyboardVisible: isKeyboardVisible,
                    key: _floatingChatKey,
                  ),

                  // Add bottom slider
                  if (showUI)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF251B2F).withOpacity(0.95)
                            : const Color(0xFFFAF9F7).withOpacity(0.95),
                        padding: ResponsiveConstants.getContentPadding(context),
                        height: ResponsiveConstants.getBottomBarHeight(context),
                        child: Row(
                          children: [
                            Text(
                              '${_calculateCurrentPage()}',
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
                                  overlayColor: Theme.of(context).brightness ==
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
                                  value: _calculateCurrentPage().toDouble(),
                                  min: 1,
                                  max: _totalPages.toDouble(),
                                  onChangeStart: (value) {
                                    _sliderDwellTimer?.cancel();
                                    _lastSliderValue = value.toInt();
                                    _isSliderInteracting = true;
                                  },
                                  onChanged: (value) {
                                    final intValue = value.toInt();
                                    if (_lastSliderValue != intValue) {
                                      _sliderDwellTimer?.cancel();
                                      _lastSliderValue = intValue;
                                      setState(() {
                                        _currentPage = intValue;
                                      });
                                      _sliderDwellTimer = Timer(
                                        const Duration(milliseconds: 200),
                                        () {
                                          if (mounted &&
                                              _lastSliderValue == intValue) {
                                            _jumpToPage(intValue);
                                          }
                                        },
                                      );
                                    }
                                  },
                                  onChangeEnd: (value) {
                                    _sliderDwellTimer?.cancel();
                                    final intValue = value.toInt();
                                    _jumpToPage(intValue);
                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
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
                              '$_totalPages',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChapter(EpubChapter chapter) {
    final chapterIndex = _flatChapters.indexOf(chapter);
    final pages = _chapterPagesCache[chapterIndex];

    if (pages == null) {
      _splitChapterIntoPages(chapterIndex);
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: pages.map((page) => _buildPage(page)).toList(),
    );
  }

  Widget _buildPage(PageContent page) {
    return SelectableRegion(
      focusNode: FocusNode(),
      selectionControls: MaterialTextSelectionControls(),
      onSelectionChanged: (selection) {
        if (!_isDisposed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed) {
              setState(() {
                _selectedText = selection?.plainText;
              });
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (page.pageNumberInChapter == 1)
              Text(
                page.chapterTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (page.pageNumberInChapter == 1) const SizedBox(height: 16),
            HtmlWidget(
              page.content,
              textStyle: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
