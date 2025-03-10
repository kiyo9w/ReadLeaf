import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/library/presentation/blocs/file_bloc.dart';
import 'package:read_leaf/features/library/presentation/widgets/file_card.dart';
import 'package:read_leaf/features/library/presentation/widgets/minimal_file_card_widget.dart';
import 'package:read_leaf/features/characters/presentation/widgets/ai_character_slider.dart';
import 'package:read_leaf/core/utils/file_utils.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:read_leaf/features/search/data/annas_archieve.dart';
import 'package:read_leaf/injection/injection.dart';
import 'package:read_leaf/features/library/domain/models/file_info.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:read_leaf/features/library/domain/models/book_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:read_leaf/features/search/presentation/blocs/search_bloc.dart';
import 'package:read_leaf/core/utils/utils.dart';
import 'package:read_leaf/features/library/presentation/widgets/refresh_animation.dart';
import 'package:read_leaf/features/characters/presentation/widgets/minimized_character_slider.dart';
import 'package:read_leaf/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:get_it/get_it.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  bool _isGeneratingMessage = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GetIt.I<GeminiService>();
    _annasArchieve = GetIt.I<AnnasArchieve>();
    _initializeScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always call generateNewAIMessage, but it will internally check if reminders are enabled
      if (_aiMessage == null && mounted) {
        generateNewAIMessage();
      }
    });
  }

  Future<void> _initializeScreen() async {
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _loadBookOfTheDay();
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
        final bookMetadataRepo = GetIt.I<BookMetadataRepository>();
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
          _isGeneratingMessage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingMessage = false;
        });
      }
      Utils.showErrorSnackBar(context, 'Error generating AI message');
      print('Error generating AI message: $e');
    }
  }

  Future<void> generateNewAIMessage() async {
    if (mounted) {
      // Check if reminders are enabled using BLoC instead of Provider
      final settingsState = context.read<SettingsBloc>().state;
      if (!settingsState.remindersEnabled) {
        // If reminders are disabled, clear any existing message but don't generate a new one
        setState(() {
          _aiMessage = null;
          _isGeneratingMessage = false;
        });
        return;
      }

      // Clear existing message first to trigger UI update
      setState(() {
        _aiMessage = null;
        _isGeneratingMessage = true;
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

  Widget _buildCharacterSlider() {
    // Check if reading reminders are enabled in the settings using BLoC
    final settingsState = context.read<SettingsBloc>().state;

    if (!_isCharacterSliderMinimized) {
      return AiCharacterSlider(
        key: AiCharacterSlider.globalKey,
        onMinimize: () {
          setState(() {
            _isCharacterSliderMinimized = true;
          });
        },
        // Only pass the AI message if reminders are enabled
        aiMessage: settingsState.remindersEnabled ? _aiMessage : null,
        isGeneratingMessage: _isGeneratingMessage,
        onContinueReading: () {
          final state = context.read<FileBloc>().state;
          if (state is FileLoaded && state.files.isNotEmpty) {
            final lastReadBook = state.files.firstWhere(
              (file) => file.wasRead,
              orElse: () => state.files.first,
            );
            context.read<FileBloc>().add(ViewFile(lastReadBook.filePath));
          }
        },
        onRemove: () {
          // Update the SettingsBloc instead of SettingsProvider
          context.read<SettingsBloc>().add(const RemindersToggled(false));
        },
        onUpdatePrompt: (newPrompt) async {
          await _geminiService.setCustomEncouragementPrompt(newPrompt);
          generateNewAIMessage();
        },
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        FileInfo? lastReadBook;
        if (state is FileLoaded) {
          if (state.lastRemovedFile != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Utils.showUndoSnackBar(
                  context,
                  'File deleted',
                  () {
                    context.read<FileBloc>().add(const UndoRemoveFile());
                  },
                );
              }
            });
          }

          if (state.files.isNotEmpty) {
            lastReadBook = state.files.firstWhere(
              (file) => file.wasRead,
              orElse: () => state.files.first,
            );
          }
        }

        return Scaffold(
          body: PullToRefreshAnimation(
            onRefresh: () async {
              await _refreshScreen();
              await _loadBookOfTheDay();
              final settingsState = context.read<SettingsBloc>().state;
              if (settingsState.remindersEnabled) {
                await generateNewAIMessage();
              }
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
                          if (_isCharacterSliderMinimized)
                            MinimizedCharacterSlider(
                              inAppBar: true,
                              onTap: () {
                                setState(() {
                                  _isCharacterSliderMinimized = false;
                                });
                              },
                            ),
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
                  child: _buildCharacterSlider(),
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
                            child: FileCard(
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
                                context
                                    .read<FileBloc>()
                                    .add(ToggleStarred(lastReadBook?.filePath));
                              },
                              title: FileCard.extractFileName(
                                  lastReadBook.filePath),
                              canDismiss: false,
                              isStarred: lastReadBook.isStarred,
                              wasRead: lastReadBook.wasRead,
                              hasBeenCompleted: lastReadBook.hasBeenCompleted,
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
                          child: Builder(builder: (context) {
                            // Get the book metadata repository
                            final bookMetadataRepo =
                                GetIt.I<BookMetadataRepository>();

                            // Create a copy of the files list that we can sort
                            final sortedFiles =
                                List<FileInfo>.from(state.files);

                            // Sort the files by last read time (most recent first)
                            sortedFiles.sort((a, b) {
                              final metadataA =
                                  bookMetadataRepo.getMetadata(a.filePath);
                              final metadataB =
                                  bookMetadataRepo.getMetadata(b.filePath);

                              // If no metadata exists, consider it as oldest (DateTime.fromMillisecondsSinceEpoch(0))
                              final timeA = metadataA?.lastReadTime ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              final timeB = metadataB?.lastReadTime ??
                                  DateTime.fromMillisecondsSinceEpoch(0);

                              // Sort descending (newest first)
                              return timeB.compareTo(timeA);
                            });

                            return ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: sortedFiles.length,
                              itemBuilder: (context, index) {
                                final file = sortedFiles[index];
                                return MinimalFileCard(
                                  filePath: file.filePath,
                                  title:
                                      FileCard.extractFileName(file.filePath),
                                  onTap: () {
                                    context
                                        .read<FileBloc>()
                                        .add(ViewFile(file.filePath));
                                  },
                                );
                              },
                            );
                          }),
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
                                searchBloc: GetIt.I<SearchBloc>(),
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
                          Future.delayed(const Duration(milliseconds: 1))
                              .then((val) {
                            context.read<FileBloc>().add(ViewFile(filePath));
                          });
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
