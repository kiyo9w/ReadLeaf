import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/FileBloc/file_bloc.dart';
import 'package:read_leaf/widgets/file_card.dart';
import 'package:read_leaf/widgets/minimal_file_card_widget.dart';
import 'package:read_leaf/widgets/ai_message_card.dart';
import 'package:read_leaf/widgets/ai_character_slider.dart';
import 'package:read_leaf/utils/file_utils.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';
import 'package:read_leaf/services/gemini_service.dart';
import 'package:read_leaf/services/annas_archieve.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/models/file_info.dart';
import 'package:read_leaf/screens/nav_screen.dart';
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:read_leaf/blocs/SearchBloc/search_bloc.dart';
import 'package:read_leaf/utils/utils.dart';
import 'package:read_leaf/widgets/animations/refresh_animation.dart';
import 'package:read_leaf/widgets/minimized_character_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final GeminiService _geminiService;
  late final AnnasArchieve _annasArchieve;
  String? _aiMessage;
  BookData? _bookOfTheDay;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;
  double _dragOffset = 0.0;
  bool _isCharacterSliderMinimized = false;

  @override
  void initState() {
    super.initState();
    _geminiService = getIt<GeminiService>();
    _annasArchieve = getIt<AnnasArchieve>();
    _initializeScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will be called when returning from other screens
    generateNewAIMessage();
  }

  Future<void> _initializeScreen() async {
    await _loadBookOfTheDay();
    // Wait for next frame to ensure FileBloc state is ready
    await Future.microtask(() async {
      if (mounted) {
        await _generateAIMessage();
        _scrollController.addListener(_scrollListener);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        _isScrollingDown = true;
        NavScreen.globalKey.currentState?.hideNavBar(true);
      }
    }
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.hideNavBar(false);
      }
    }
  }

  Future<void> _loadBookOfTheDay() async {
    try {
      final books = await _annasArchieve.searchBooks(
        searchQuery: "Nexus - A brief history of Information Networks",
        enableFilters: false,
      );
      if (books.isNotEmpty) {
        setState(() {
          _bookOfTheDay = books.first;
        });
      }
    } catch (e) {
      Utils.showErrorSnackBar(context, 'Error loading book of the day');
      print('Error loading book of the day: $e');
    }
  }

  Future<void> _generateAIMessage() async {
    try {
      final state = context.read<FileBloc>().state;
      String bookTitle = '';
      int currentPage = 1;
      int totalPages = 1;

      if (state is FileLoaded && state.files.isNotEmpty) {
        final lastReadBook = state.files.firstWhere(
          (file) => file.wasRead,
          orElse: () => state.files.first,
        );
        bookTitle = FileCard.extractFileName(lastReadBook.filePath);

        // Get actual page numbers from book metadata
        final bookMetadataRepo = getIt<BookMetadataRepository>();
        final metadata = bookMetadataRepo.getMetadata(lastReadBook.filePath);
        if (metadata != null) {
          currentPage = metadata.lastOpenedPage;
          totalPages = metadata.totalPages;
        } else {
          // If no metadata exists, create it with default values
          final fileType = path
              .extension(lastReadBook.filePath)
              .toLowerCase()
              .replaceAll('.', '');
          final newMetadata = BookMetadata(
            filePath: lastReadBook.filePath,
            title: bookTitle,
            totalPages: 1,
            lastReadTime: DateTime.now(),
            fileType: fileType,
          );
          await bookMetadataRepo.saveMetadata(newMetadata);
        }
      }

      final message = await _geminiService.askAboutText(
        '', // No selected text needed for encouragement
        customPrompt: '', // Let the character's personality shine
        bookTitle: bookTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        task: 'encouragement', // Use the encouragement prompt
      );

      if (mounted) {
        setState(() {
          _aiMessage = message;
        });
      }
    } catch (e) {
      Utils.showErrorSnackBar(context, 'Error generating AI message');
      print('Error generating AI message: $e');
    }
  }

  // Make this method public so it can be called from the character slider
  Future<void> generateNewAIMessage() async {
    if (mounted) {
      // Clear existing message first to trigger UI update
      setState(() {
        _aiMessage = null;
      });
      // Generate new message after a short delay
      await Future.delayed(const Duration(milliseconds: 100));
      await _generateAIMessage();
    }
  }

  Future<void> _refreshScreen() async {
    setState(() {
      // This will trigger a rebuild of the entire screen
      // including the AiCharacterSlider
    });
  }

  void _updateDragOffset(double offset) {
    final shouldHide = offset > 20;
    if (shouldHide != (_dragOffset > 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _dragOffset = shouldHide ? offset : 0;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        FileInfo? lastReadBook;
        if (state is FileLoaded && state.files.isNotEmpty) {
          lastReadBook = state.files.firstWhere(
            (file) => file.wasRead,
            orElse: () => state.files.first,
          );
        }

        return Scaffold(
          body: PullToRefreshAnimation(
            onRefresh: () async {
              await _refreshScreen();
              await _loadBookOfTheDay();
              await generateNewAIMessage();
              setState(() {
                _dragOffset = 0;
              });
            },
            onPull: _updateDragOffset, // Add this callback
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  elevation: _dragOffset > 0 ? 0 : null,
                  backgroundColor: _dragOffset > 0
                      ? Colors.transparent
                      : Theme.of(context).appBarTheme.backgroundColor,
                  title: AnimatedOpacity(
                    opacity: _dragOffset > 0 ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/app_logo/logo_nobg.png',
                          width: 72,
                          height: 72,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Leafy reader',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    AnimatedOpacity(
                      opacity: _dragOffset > 0 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              IconButton(
                                icon: Icon(Icons.card_giftcard,
                                    color: Theme.of(context).iconTheme.color),
                                onPressed: () {},
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    '3',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.more_vert,
                                color: Theme.of(context).iconTheme.color),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _isCharacterSliderMinimized
                      ? MinimizedCharacterSlider(
                          onTap: () {
                            setState(() {
                              _isCharacterSliderMinimized = false;
                            });
                          },
                        )
                      : AiCharacterSlider(
                          onMinimize: () {
                            setState(() {
                              _isCharacterSliderMinimized = true;
                            });
                          },
                        ),
                ),
                if (lastReadBook != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last read',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                FileCard(
                                  filePath: lastReadBook.filePath,
                                  fileSize: lastReadBook.fileSize,
                                  isSelected: false,
                                  onSelected: () {},
                                  onView: () {
                                    context
                                        .read<FileBloc>()
                                        .add(ViewFile(lastReadBook!.filePath));
                                  },
                                  onRemove: () {},
                                  onDownload: () {},
                                  onStar: () {
                                    context.read<FileBloc>().add(
                                        ToggleStarred(lastReadBook?.filePath));
                                  },
                                  title: FileCard.extractFileName(
                                      lastReadBook.filePath),
                                  canDismiss: false,
                                  isStarred: lastReadBook.isStarred,
                                  wasRead: lastReadBook.wasRead,
                                  hasBeenCompleted:
                                      lastReadBook.hasBeenCompleted,
                                ),
                                if (_aiMessage != null)
                                  AIMessageCard(
                                    message: _aiMessage!,
                                    onContinue: () {
                                      context.read<FileBloc>().add(
                                          ViewFile(lastReadBook!.filePath));
                                    },
                                    skipAnimation: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: Text(
                          'Your books',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (state is FileLoaded)
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: state.files.length,
                            itemBuilder: (context, index) {
                              final file = state.files[index];
                              return MinimalFileCard(
                                filePath: file.filePath,
                                title: FileCard.extractFileName(file.filePath),
                                onTap: () {
                                  context
                                      .read<FileBloc>()
                                      .add(ViewFile(file.filePath));
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                if (_bookOfTheDay != null)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                          child: Text(
                            'Book of the day',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FileCard(
                            filePath: _bookOfTheDay!.link,
                            fileSize: 0,
                            isSelected: false,
                            onSelected: () {},
                            onView: () {
                              FileUtils.handleBookClick(
                                url: _bookOfTheDay!.link,
                                context: context,
                                searchBloc: getIt<SearchBloc>(),
                                annasArchieve: _annasArchieve,
                              );
                            },
                            onRemove: () {},
                            onDownload: () {},
                            onStar: () {
                              context
                                  .read<FileBloc>()
                                  .add(ToggleStarred(lastReadBook?.filePath));
                            },
                            title: _bookOfTheDay!.title,
                            isInternetBook: true,
                            author: _bookOfTheDay!.author,
                            thumbnailUrl: _bookOfTheDay!.thumbnail,
                            canDismiss: false,
                            isStarred: false,
                            wasRead: false,
                            hasBeenCompleted: false,
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    splashColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    highlightColor:
                        Theme.of(context).primaryColor.withOpacity(0.05),
                    onTap: () async {
                      final filePath = await FileUtils.picker();
                      if (filePath != null) {
                        if (mounted) {
                          context.read<FileBloc>().add(LoadFile(filePath));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              color: Theme.of(context).colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            'Add book',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
