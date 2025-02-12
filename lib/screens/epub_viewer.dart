import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:read_leaf/services/book_metadata_repository.dart';
import 'package:read_leaf/models/book_metadata.dart';
import 'package:read_leaf/services/thumbnail_service.dart';
import 'package:read_leaf/constants/responsive_constants.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';

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
  StreamSubscription? _locatorSubscription;

  BookMetadata? _metadata;
  bool _isLoading = true;
  String? _selectedText;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NavScreen.globalKey.currentState?.setNavBarVisibility(true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeReader();
  }

  Future<void> _initializeReader() async {
    if (!mounted) return;

    try {
      await _loadEpub();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing reader: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locatorSubscription?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });
    super.dispose();
  }

  Future<void> _updateMetadata(Map<String, dynamic> locator) async {
    if (_metadata == null || _isDisposed) return;

    try {
      final lastPage = locator['locations']?['cfi']?.toString();
      final lastPageInt = int.tryParse(lastPage ?? '') ??
          int.tryParse(_metadata!.lastOpenedPage?.toString() ?? '') ??
          1;

      final updatedMetadata = _metadata!.copyWith(
        lastOpenedPage: lastPageInt,
        lastReadTime: DateTime.now(),
        readingProgress: 0.0,
      );

      await _metadataRepository.saveMetadata(updatedMetadata);
      if (!_isDisposed && mounted) {
        setState(() {
          _metadata = updatedMetadata;
        });
      }
    } catch (e) {
      print('Error updating metadata: $e');
    }
  }

  Future<void> _loadEpub() async {
    if (_isDisposed) return;

    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

    try {
      // Get or create metadata
      BookMetadata? metadata = _metadataRepository.getMetadata(state.file.path);
      if (metadata == null) {
        metadata = BookMetadata(
          filePath: state.file.path,
          title: path.basename(state.file.path),
          author: '',
          totalPages: 0,
          lastReadTime: DateTime.now(),
          fileType: 'epub',
        );
        await _metadataRepository.saveMetadata(metadata);
      }

      if (!_isDisposed) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
        });
      }

      // Configure and open the EPUB viewer
      VocsyEpub.setConfig(
        themeColor: Theme.of(context).primaryColor,
        identifier: path.basenameWithoutExtension(state.file.path),
        scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
        allowSharing: true,
        enableTts: true,
        nightMode: Theme.of(context).brightness == Brightness.dark,
      );

      // Listen for location changes
      _locatorSubscription?.cancel(); // Cancel any existing subscription
      _locatorSubscription = VocsyEpub.locatorStream.listen((locator) {
        if (!_isDisposed && mounted) {
          try {
            Map<String, dynamic> locatorMap;

            if (locator is int) {
              locatorMap = {
                "locations": {"cfi": locator.toString()}
              };
            } else if (locator is String) {
              try {
                locatorMap = jsonDecode(locator);
              } catch (e) {
                locatorMap = {
                  "locations": {"cfi": locator}
                };
              }
            } else {
              print('Unexpected locator type: ${locator.runtimeType}');
              return;
            }

            _updateMetadata(locatorMap);

            // Update the current page in the bloc
            final pageNumber = int.tryParse(
                    locatorMap['locations']?['cfi']?.toString() ?? '1') ??
                1;
            if (mounted) {
              context.read<ReaderBloc>().add(JumpToPage(pageNumber));
            }
          } catch (e) {
            print('Error handling locator update: $e');
          }
        }
      });

      // Open the EPUB file
      if (metadata.lastOpenedPage != null) {
        VocsyEpub.open(
          state.file.path,
          lastLocation: EpubLocator.fromJson({
            "bookId": path.basenameWithoutExtension(state.file.path),
            "href": "/OEBPS/ch01.xhtml",
            "created": DateTime.now().millisecondsSinceEpoch,
            "locations": {"cfi": metadata.lastOpenedPage.toString()}
          }),
        );
      } else {
        VocsyEpub.open(state.file.path);
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        Utils.showErrorSnackBar(context, 'Error loading EPUB: $e');
      }
    }
  }

  void _handleChatMessage(String? message, {String? selectedText}) async {
    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return;

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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listener: (context, state) {
        if (state is ReaderLoaded && _isLoading) {
          Future.microtask(() {
            if (!_isDisposed && mounted) {
              _loadEpub();
            }
          });
        }
      },
      builder: (context, state) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is! ReaderLoaded) {
          return const Scaffold(
            body: Center(child: Text('Reader not loaded')),
          );
        }

        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;

        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              try {
                if (mounted) {
                  context.read<ReaderBloc>().add(CloseReader());
                  context.read<FileBloc>().add(CloseViewer());
                }
              } catch (e) {
                print('Error handling pop: $e');
              }
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                // The EPUB viewer is handled by the native implementation
                const SizedBox.expand(),

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
                  bookTitle: path.basename(state.file.path),
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
