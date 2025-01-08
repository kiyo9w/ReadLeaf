import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/widgets/file_card.dart';
import 'package:migrated/widgets/minimal_file_card_widget.dart';
import 'package:migrated/widgets/ai_message_card.dart';
import 'package:migrated/widgets/ai_character_slider.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';
import 'package:migrated/services/gemini_service.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/screens/nav_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GeminiService _geminiService;
  late final AnnasArchieve _annasArchieve;
  String? _aiMessage;
  BookData? _bookOfTheDay;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    _annasArchieve = getIt<AnnasArchieve>();
    _loadBookOfTheDay();
    _generateAIMessage();
    _scrollController.addListener(_scrollListener);
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
        NavScreen.globalKey.currentState?.setNavBarVisibility(true);
      }
    }
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.setNavBarVisibility(false);
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
      print('Error loading book of the day: $e');
    }
  }

  Future<void> _generateAIMessage() async {
    try {
      final state = context.read<FileBloc>().state;
      String bookTitle = '';

      if (state is FileLoaded && state.files.isNotEmpty) {
        final lastReadBook = state.files.firstWhere(
          (file) => file.wasRead,
          orElse: () => state.files.first,
        );
        bookTitle = FileCard.extractFileName(lastReadBook.filePath);
      }

      final message = await _geminiService.askAboutText(
        '', // No selected text needed for encouragement
        customPrompt: '', // Let the character's personality shine
        bookTitle: bookTitle,
        currentPage: 1,
        totalPages: 1,
        task: 'encouragement', // Use the encouragement prompt
      );

      if (mounted) {
        setState(() {
          _aiMessage = message;
        });
      }
    } catch (e) {
      print('Error generating AI message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileBloc, FileState>(
      listener: (context, state) {
        if (state is FileViewing) {
          final file = File(state.filePath);
          context.read<ReaderBloc>().add(
                OpenReader('', file: file, filePath: state.filePath),
              );
          Navigator.pushNamed(context, '/viewer');
        }
      },
      builder: (context, state) {
        FileInfo? lastReadBook;
        if (state is FileLoaded && state.files.isNotEmpty) {
          lastReadBook = state.files.firstWhere(
            (file) => file.wasRead,
            orElse: () => state.files.first,
          );
        }

        return Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.white,
                title: Row(
                  children: [
                    Image.asset(
                      'assets/images/leafy_icon.png',
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Leafy reader',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.card_giftcard,
                            color: Colors.black),
                        onPressed: () {},
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
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
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 8),
                  child: AiCharacterSlider(),
                ),
              ),
              if (lastReadBook != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last read',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5F4),
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
                                onStar: () {},
                                title: FileCard.extractFileName(
                                    lastReadBook.filePath),
                              ),
                              if (_aiMessage != null)
                                AIMessageCard(
                                  message: _aiMessage!,
                                  onContinue: () {
                                    context
                                        .read<FileBloc>()
                                        .add(ViewFile(lastReadBook!.filePath));
                                  },
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
                          onView: () {},
                          onRemove: () {},
                          onDownload: () {},
                          onStar: () {},
                          title: _bookOfTheDay!.title,
                          isInternetBook: true,
                          author: _bookOfTheDay!.author,
                          thumbnailUrl: _bookOfTheDay!.thumbnail,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final filePath = await FileUtils.picker();
              if (filePath != null) {
                if (mounted) {
                  context.read<FileBloc>().add(LoadFile(filePath));
                }
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
