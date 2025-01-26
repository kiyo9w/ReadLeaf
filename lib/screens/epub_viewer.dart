import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/services/gemini_service.dart';
import 'package:get_it/get_it.dart';
import 'package:migrated/widgets/CompanionChat/floating_chat_widget.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/utils/utils.dart';
import 'package:path/path.dart' as path;
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:migrated/services/book_metadata_repository.dart';
import 'package:migrated/models/book_metadata.dart';
import 'package:migrated/services/thumbnail_service.dart';

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
        });
      }

      // Update the current page in the bloc and metadata
      if (mounted) {
        final page = _currentChapterIndex + 1;
        context.read<ReaderBloc>().add(JumpToPage(page));
        _updateMetadata(page);
      }
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

  Future<bool> _handleBackPress() async {
    try {
      // Save current progress before popping
      if (_metadata != null) {
        await _updateMetadata(_currentChapterIndex + 1);
      }
      if (mounted) {
        context.read<ReaderBloc>().add(CloseReader());
        context.read<FileBloc>().add(CloseViewer());
        Navigator.of(context).pop();
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

        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;

        return WillPopScope(
          onWillPop: _handleBackPress,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: const Color(0xffDDDDDD),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBackPress,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _epubBook?.Title ?? 'Reading',
                    style: const TextStyle(fontSize: 18, color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_epubBook?.Author != null)
                    Text(
                      _epubBook!.Author!,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: () {
                    setState(() {
                      _showChapters = !_showChapters;
                    });
                  },
                ),
                if (state is ReaderLoaded)
                  PopupMenuButton<String>(
                    elevation: 0,
                    color: const Color(0xffDDDDDD),
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
                    ],
                  ),
              ],
            ),
            body: Stack(
              children: [
                Row(
                  children: [
                    if (_showChapters)
                      Container(
                        width: 280,
                        color: Colors.grey.shade100,
                        child: Column(
                          children: [
                            if (_coverImage != null)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: _coverImage!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
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
                                            : null,
                                      ),
                                    ),
                                    onTap: () async {
                                      await _scrollController.scrollTo(
                                        index: index,
                                        duration:
                                            const Duration(milliseconds: 300),
                                      );
                                      if (MediaQuery.of(context).size.width <
                                              600 &&
                                          mounted) {
                                        setState(() {
                                          _showChapters = false;
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ScrollablePositionedList.builder(
                        itemCount: _flatChapters.length,
                        itemBuilder: (context, index) {
                          final chapter = _flatChapters[index];
                          return SelectableRegion(
                            focusNode: FocusNode(),
                            selectionControls: MaterialTextSelectionControls(),
                            onSelectionChanged: (selection) {
                              if (!_isDisposed) {
                                setState(() {
                                  _selectedText = selection?.plainText;
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chapter.Title ?? 'Chapter ${index + 1}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  HtmlWidget(
                                    chapter.HtmlContent ?? '',
                                    textStyle: TextStyle(
                                      fontSize: 16,
                                      height: 1.6,
                                      color: state is ReaderLoaded &&
                                              state.readingMode ==
                                                  ReadingMode.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        itemScrollController: _scrollController,
                        itemPositionsListener: _positionsListener,
                      ),
                    ),
                  ],
                ),
                if (_selectedText?.isNotEmpty == true)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        _handleChatMessage(null, selectedText: _selectedText);
                      },
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('Ask AI',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
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
                          'encouragement': 'You\'re doing great! Keep reading!',
                        },
                      ),
                  onSendMessage: _handleChatMessage,
                  bookId: state is ReaderLoaded ? state.file.path : '',
                  bookTitle: _epubBook?.Title ?? '',
                  keyboardHeight: keyboardHeight,
                  isKeyboardVisible: isKeyboardVisible,
                  key: _floatingChatKey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
