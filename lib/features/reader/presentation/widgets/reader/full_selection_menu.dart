import 'package:flutter/material.dart';
import 'package:read_leaf/features/reader/presentation/widgets/reader/floating_selection_menu.dart';
import 'package:read_leaf/features/companion_chat/data/gemini_service.dart';
import 'package:read_leaf/features/reader/data/text_selection_service.dart';
import 'package:get_it/get_it.dart';
import 'package:read_leaf/features/companion_chat/presentation/widgets/floating_chat_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';
import 'package:path/path.dart' as path;

class FullSelectionMenu extends StatefulWidget {
  final String selectedText;
  final SelectionMenuType menuType;
  final VoidCallback? onDismiss;
  final GlobalKey<FloatingChatWidgetState>? floatingChatKey;

  const FullSelectionMenu({
    super.key,
    required this.selectedText,
    required this.menuType,
    this.onDismiss,
    this.floatingChatKey,
  });

  @override
  State<FullSelectionMenu> createState() => _FullSelectionMenuState();
}

class _FullSelectionMenuState extends State<FullSelectionMenu> {
  late double _initialHeight;
  late double _maxHeight;
  bool _isExpanded = false;
  final TextEditingController _customInstructionsController =
      TextEditingController();
  bool _isLoading = false;
  String? _selectedOption;

  // Service instances
  late final _geminiService = GetIt.I<GeminiService>();
  late final _textSelectionService = GetIt.I<TextSelectionService>();

  @override
  void initState() {
    super.initState();
    _setupInitialContent();
  }

  @override
  void dispose() {
    _customInstructionsController.dispose();
    super.dispose();
  }

  void _setupInitialContent() {
    switch (widget.menuType) {
      case SelectionMenuType.translate:
        _customInstructionsController.text = 'Translate to Spanish';
        _selectedOption = 'Spanish';
        break;
      case SelectionMenuType.dictionary:
        _customInstructionsController.text = 'Define this word';
        break;
      case SelectionMenuType.wikipedia:
        _customInstructionsController.text = 'Find information about this';
        break;
      case SelectionMenuType.generateImage:
        _customInstructionsController.text = 'Generate an image of this';
        _selectedOption = 'Realistic';
        break;
      case SelectionMenuType.askAi:
        _customInstructionsController.text = '';
        break;
      default:
        _customInstructionsController.text = '';
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupDimensions();
  }

  void _setupDimensions() {
    final screenHeight = MediaQuery.of(context).size.height;
    _initialHeight = screenHeight * 0.55; // 55% of screen height initially
    _maxHeight = screenHeight * 0.9; // 90% of screen height when expanded
  }

  String _getMenuTitle() {
    switch (widget.menuType) {
      case SelectionMenuType.askAi:
        return 'Ask AI Assistant';
      case SelectionMenuType.translate:
        return 'Translate';
      case SelectionMenuType.highlight:
        return 'Highlight';
      case SelectionMenuType.dictionary:
        return 'Dictionary';
      case SelectionMenuType.wikipedia:
        return 'Wikipedia';
      case SelectionMenuType.audio:
        return 'Audio';
      case SelectionMenuType.generateImage:
        return 'Generate Images';
    }
  }

  IconData _getMenuIcon() {
    switch (widget.menuType) {
      case SelectionMenuType.askAi:
        return Icons.chat_bubble_outline;
      case SelectionMenuType.translate:
        return Icons.translate;
      case SelectionMenuType.highlight:
        return Icons.highlight;
      case SelectionMenuType.dictionary:
        return Icons.book_outlined;
      case SelectionMenuType.wikipedia:
        return Icons.menu_book_outlined;
      case SelectionMenuType.audio:
        return Icons.volume_up_outlined;
      case SelectionMenuType.generateImage:
        return Icons.image_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {}, // Prevent tap from propagating
          child: Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: EdgeInsets.zero,
            backgroundColor: isDark ? const Color(0xFF251B2F) : Colors.white,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                width: MediaQuery.of(context).size.width,
                constraints: BoxConstraints(
                  maxHeight: _isExpanded ? _maxHeight : _initialHeight,
                  maxWidth: 500,
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final contentHeight = keyboardVisible
                        ? availableHeight - 180
                        : availableHeight;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header - Always visible
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getMenuIcon(),
                                  color: isDark
                                      ? const Color(0xFFAA96B6)
                                      : Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _getMenuTitle(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                    ),
                  ],
                ),
                            Row(
                  children: [
                                IconButton(
                                  icon: Icon(
                                    _isExpanded
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  onPressed: widget.onDismiss,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Book info if in reader
                        if (context.read<ReaderBloc>().state is ReaderLoaded)
                          _buildBookInfoSection(context, isDark),
                        if (context.read<ReaderBloc>().state is ReaderLoaded)
                          const SizedBox(height: 16),

                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Selected text section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Text',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF352A3B)
                                                .withOpacity(0.3)
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF352A3B)
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                        padding: const EdgeInsets.all(16),
                                      width: double.infinity,
                                      child: SelectableText(
                                        widget.selectedText,
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Custom instructions section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getInstructionsLabel(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _customInstructionsController,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        hintText: _getInstructionsHint(),
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF352A3B)
                                                .withOpacity(0.3)
                                            : Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF352A3B)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF352A3B)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFFAA96B6)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Options section
                                if (_shouldShowOptions())
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Options',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildOptionsContent(),
                                    ],
                                  ),
                                if (_shouldShowOptions())
                                  const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),

                        // Action buttons
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: widget.onDismiss,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                foregroundColor: isDark
                                    ? const Color(0xFF8E8E93)
                                    : Colors.grey[600],
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleAction,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                backgroundColor: isDark
                                    ? const Color(0xFFAA96B6)
                                    : Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getActionIcon(), size: 18),
                                        const SizedBox(width: 8),
                                        Text(_getActionButtonText()),
                                      ],
                                    ),
                            ),
                          ],
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
  }

  Widget _buildBookInfoSection(BuildContext context, bool isDark) {
    final state = context.read<ReaderBloc>().state;
    if (state is! ReaderLoaded) return const SizedBox();

    final bookTitle = path.basename(state.file.path);
    final currentPage = state.currentPage;
    final totalPages = state.totalPages;

    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bookTitle.length > 30
                ? '${bookTitle.substring(0, 27)}...'
                : bookTitle,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF352A3B).withOpacity(0.5)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
            child: Text(
            '$currentPage/$totalPages',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _getInstructionsLabel() {
    switch (widget.menuType) {
      case SelectionMenuType.translate:
        return 'Translation Settings';
      case SelectionMenuType.dictionary:
        return 'Dictionary Source';
      case SelectionMenuType.wikipedia:
        return 'Search Parameters';
      case SelectionMenuType.askAi:
        return 'Custom Instructions';
      case SelectionMenuType.generateImage:
        return 'Image Settings';
      default:
        return 'Options';
    }
  }

  String _getInstructionsHint() {
    switch (widget.menuType) {
      case SelectionMenuType.translate:
        return 'Example: Translate to Spanish\nOr: Translate to French and explain idioms';
      case SelectionMenuType.dictionary:
        return 'Example: Show advanced definitions\nOr: Include etymology';
      case SelectionMenuType.wikipedia:
        return 'Example: Find detailed information\nOr: Focus on historical context';
      case SelectionMenuType.askAi:
        return 'Example: Explain this in simple terms\nOr: Analyze the literary techniques used';
      case SelectionMenuType.generateImage:
        return 'Example: Create a realistic image\nOr: Generate in anime style';
      default:
        return 'Enter your preferences here';
    }
  }

  bool _shouldShowOptions() {
    return widget.menuType == SelectionMenuType.translate ||
        widget.menuType == SelectionMenuType.generateImage ||
        widget.menuType == SelectionMenuType.dictionary;
  }

  Widget _buildOptionsContent() {
    if (widget.menuType == SelectionMenuType.translate) {
      return _buildLanguageOptions();
    } else if (widget.menuType == SelectionMenuType.generateImage) {
      return _buildImageStyleOptions();
    } else if (widget.menuType == SelectionMenuType.dictionary) {
      return _buildDictionaryOptions();
    }
    return const SizedBox();
  }

  Widget _buildLanguageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildOptionChip('English', isDark, _selectedOption == 'English',
            (value) {
          setState(() {
            _selectedOption = value ? 'English' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to English';
            }
          });
        }),
        _buildOptionChip('Spanish', isDark, _selectedOption == 'Spanish',
            (value) {
          setState(() {
            _selectedOption = value ? 'Spanish' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to Spanish';
            }
          });
        }),
        _buildOptionChip('French', isDark, _selectedOption == 'French',
            (value) {
          setState(() {
            _selectedOption = value ? 'French' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to French';
            }
          });
        }),
        _buildOptionChip('German', isDark, _selectedOption == 'German',
            (value) {
          setState(() {
            _selectedOption = value ? 'German' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to German';
            }
          });
        }),
        _buildOptionChip('Chinese', isDark, _selectedOption == 'Chinese',
            (value) {
          setState(() {
            _selectedOption = value ? 'Chinese' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to Chinese';
            }
          });
        }),
        _buildOptionChip('Japanese', isDark, _selectedOption == 'Japanese',
            (value) {
          setState(() {
            _selectedOption = value ? 'Japanese' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to Japanese';
            }
          });
        }),
        _buildOptionChip('Russian', isDark, _selectedOption == 'Russian',
            (value) {
          setState(() {
            _selectedOption = value ? 'Russian' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to Russian';
            }
          });
        }),
        _buildOptionChip('Arabic', isDark, _selectedOption == 'Arabic',
            (value) {
          setState(() {
            _selectedOption = value ? 'Arabic' : null;
            if (value) {
              _customInstructionsController.text = 'Translate to Arabic';
            }
          });
        }),
      ],
    );
  }

  Widget _buildDictionaryOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildOptionChip('English', isDark, _selectedOption == 'English',
            (value) {
          setState(() {
            _selectedOption = value ? 'English' : null;
            if (value) {
              _customInstructionsController.text = 'Define in English';
            }
          });
        }),
        _buildOptionChip('Spanish', isDark, _selectedOption == 'Spanish',
            (value) {
          setState(() {
            _selectedOption = value ? 'Spanish' : null;
            if (value) {
              _customInstructionsController.text = 'Define in Spanish';
            }
          });
        }),
        _buildOptionChip('French', isDark, _selectedOption == 'French',
            (value) {
          setState(() {
            _selectedOption = value ? 'French' : null;
            if (value) {
              _customInstructionsController.text = 'Define in French';
            }
          });
        }),
        _buildOptionChip('Etymology', isDark, _selectedOption == 'Etymology',
            (value) {
          setState(() {
            _selectedOption = value ? 'Etymology' : null;
            if (value) {
              _customInstructionsController.text = 'Show word etymology';
            }
          });
        }),
        _buildOptionChip(
            'Example Uses', isDark, _selectedOption == 'Example Uses', (value) {
          setState(() {
            _selectedOption = value ? 'Example Uses' : null;
            if (value) {
              _customInstructionsController.text = 'Show example uses';
            }
          });
        }),
      ],
    );
  }

  Widget _buildImageStyleOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildOptionChip('Realistic', isDark, _selectedOption == 'Realistic',
            (value) {
          setState(() {
            _selectedOption = value ? 'Realistic' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a realistic image of this';
            }
          });
        }),
        _buildOptionChip('Cartoon', isDark, _selectedOption == 'Cartoon',
            (value) {
          setState(() {
            _selectedOption = value ? 'Cartoon' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a cartoon-style image of this';
            }
          });
        }),
        _buildOptionChip('Anime', isDark, _selectedOption == 'Anime', (value) {
          setState(() {
            _selectedOption = value ? 'Anime' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate an anime-style image of this';
            }
          });
        }),
        _buildOptionChip('Watercolor', isDark, _selectedOption == 'Watercolor',
            (value) {
          setState(() {
            _selectedOption = value ? 'Watercolor' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a watercolor painting of this';
            }
          });
        }),
        _buildOptionChip('3D Render', isDark, _selectedOption == '3D Render',
            (value) {
          setState(() {
            _selectedOption = value ? '3D Render' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a 3D render of this';
            }
          });
        }),
        _buildOptionChip('Sketch', isDark, _selectedOption == 'Sketch',
            (value) {
          setState(() {
            _selectedOption = value ? 'Sketch' : null;
            if (value) {
              _customInstructionsController.text = 'Generate a sketch of this';
            }
          });
        }),
        _buildOptionChip('Pop Art', isDark, _selectedOption == 'Pop Art',
            (value) {
          setState(() {
            _selectedOption = value ? 'Pop Art' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a pop art image of this';
            }
          });
        }),
        _buildOptionChip('Cyberpunk', isDark, _selectedOption == 'Cyberpunk',
            (value) {
          setState(() {
            _selectedOption = value ? 'Cyberpunk' : null;
            if (value) {
              _customInstructionsController.text =
                  'Generate a cyberpunk-style image of this';
            }
          });
        }),
      ],
    );
  }

  Widget _buildOptionChip(
      String label, bool isDark, bool isSelected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor:
          isDark ? const Color(0xFF352A3B).withOpacity(0.6) : Colors.grey[100],
      selectedColor: isDark
          ? const Color(0xFFAA96B6).withOpacity(0.4)
          : Theme.of(context).colorScheme.primary.withOpacity(0.15),
      checkmarkColor: isDark
          ? const Color(0xFFAA96B6)
          : Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? (isDark
                ? const Color(0xFFAA96B6)
                : Theme.of(context).colorScheme.primary)
            : (isDark ? Colors.grey[300] : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? (isDark
                  ? const Color(0xFFAA96B6)
                  : Theme.of(context).colorScheme.primary)
              : Colors.transparent,
          width: 1,
        ),
      ),
      onSelected: onSelected,
    );
  }

  IconData _getActionIcon() {
    switch (widget.menuType) {
      case SelectionMenuType.askAi:
        return Icons.chat_bubble_outline;
      case SelectionMenuType.translate:
        return Icons.translate;
      case SelectionMenuType.dictionary:
        return Icons.book_outlined;
      case SelectionMenuType.wikipedia:
        return Icons.search;
      case SelectionMenuType.generateImage:
        return Icons.image_outlined;
      default:
        return Icons.check;
    }
  }

  String _getActionButtonText() {
    switch (widget.menuType) {
      case SelectionMenuType.askAi:
        return 'Ask AI';
      case SelectionMenuType.translate:
        return 'Translate';
      case SelectionMenuType.dictionary:
        return 'Look Up';
      case SelectionMenuType.wikipedia:
        return 'Search';
      case SelectionMenuType.generateImage:
        return 'Generate';
      default:
        return 'Submit';
    }
  }

  Future<void> _handleAction() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      switch (widget.menuType) {
        case SelectionMenuType.askAi:
          await _handleAskAi();
          break;
        case SelectionMenuType.translate:
          await _handleTranslate();
          break;
        case SelectionMenuType.dictionary:
          await _handleDictionary();
          break;
        case SelectionMenuType.wikipedia:
          await _handleWikipedia();
          break;
        case SelectionMenuType.generateImage:
          await _handleGenerateImage();
          break;
        default:
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Retrieves current book information from ReaderBloc
  BookContext _getBookContext() {
    String bookTitle = widget.menuType.defaultBookTitle;
    int currentPage = 1;
    int totalPages = 1;

    try {
      final state = context.read<ReaderBloc>().state;
      if (state is ReaderLoaded) {
        bookTitle = path.basename(state.file.path);
        currentPage = state.currentPage;
        totalPages = state.totalPages;
      }
    } catch (e) {
      print('Error accessing ReaderBloc: $e');
    }

    return BookContext(
        title: bookTitle, currentPage: currentPage, totalPages: totalPages);
  }

  /// Safe execution of chat operation through the TextSelectionService
  Future<void> _executeTextSelectionOperation() async {
    // Get all required data before closing dialog
    final selectedText = widget.selectedText;
    final menuType = widget.menuType;
    final chatKey = widget.floatingChatKey;
    final customInstructions = _customInstructionsController.text.trim();
    final bookContext = _getBookContext();

    // Close dialog and THEN handle the async operations
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }

    // Use microtask to ensure this runs after the dialog is fully dismissed
    Future.microtask(() async {
      if (chatKey?.currentState == null) return;

      try {
        // Format query with selected text visually distinct
        final query = _formatUserPrompt(
          selectedText: selectedText,
          menuType: menuType,
          customInstructions: customInstructions,
          selectedOption: _selectedOption,
        );

        // Show chat and add user message
        chatKey!.currentState!.showChat();
        chatKey.currentState!.addUserMessage(query);

        // Use unified TextSelectionService to handle the operation
        final textSelectionService = GetIt.I<TextSelectionService>();
        final result = await textSelectionService.handleSelection(
          text: selectedText,
          menuType: menuType,
          customPrompt: customInstructions,
          selectedOption: _selectedOption,
          bookTitle: bookContext.title,
          currentPage: bookContext.currentPage,
          totalPages: bookContext.totalPages,
        );

        // Format and show response if chat is still available
        if (chatKey.currentState != null) {
          final responseMessage = _formatResponseMessage(result, menuType);
          chatKey.currentState!.addAiResponse(responseMessage);
        }
      } catch (e) {
        print('Error in ${menuType.name} operation: $e');
        if (chatKey!.currentState != null) {
          chatKey.currentState!.addAiResponse(
              "**Error**\n\nI couldn't complete the operation. Please try again.");
        }
      }
    });
  }

  /// Format user prompt with consistent selected text display
  String _formatUserPrompt({
    required String selectedText,
    required SelectionMenuType menuType,
    required String? customInstructions,
    required String? selectedOption,
  }) {
    // Always start with selected text
    final buffer = StringBuffer('Selected text: "_$selectedText"_\n\n');

    // Add custom instructions or default prompt based on menu type
    switch (menuType) {
      case SelectionMenuType.askAi:
        if (customInstructions?.isNotEmpty == true) {
          buffer.write(customInstructions);
        } else {
          buffer.write('Please analyze this.');
        }
        break;

      case SelectionMenuType.translate:
        final language = selectedOption ?? 'Spanish';
        buffer.write('Translate to $language');
        break;

      case SelectionMenuType.dictionary:
        buffer.write('Look up in dictionary');
        break;

      case SelectionMenuType.wikipedia:
        buffer.write('Search Wikipedia');
        break;

      case SelectionMenuType.generateImage:
        final style = selectedOption ?? 'Realistic';
        buffer.write('Generate image in $style style');
        break;

      default:
        if (customInstructions?.isNotEmpty == true) {
          buffer.write(customInstructions);
        }
    }

    return buffer.toString();
  }

  /// Format the AI response based on menu type and result
  String _formatResponseMessage(
      Map<String, dynamic> result, SelectionMenuType menuType) {
    if (result['success'] != true) {
      return "**Error**\n\n${result['error'] ?? 'An unexpected error occurred.'}";
    }

    switch (menuType) {
      case SelectionMenuType.askAi:
        return result['response'] as String;

      case SelectionMenuType.translate:
        final language = _selectedOption ?? 'Spanish';
        return "**Translation to $language**\n\n${result['translation']}";

      case SelectionMenuType.dictionary:
        if (result['source'] == 'gemini') {
          return "**Dictionary Lookup**\n\n${result['data']}";
        } else {
          final data = result['data'][0];
          final word = data['word'] ?? widget.selectedText;
          final phonetic = data['phonetic'] ?? '';

          final buffer = StringBuffer("**Dictionary: $word** $phonetic\n\n");

          if (data['meanings'] != null) {
            for (var meaning in data['meanings']) {
              final partOfSpeech = meaning['partOfSpeech'];
              buffer.write("• *$partOfSpeech*\n");

              for (var definition in meaning['definitions']) {
                buffer.write("  - ${definition['definition']}\n");
                if (definition['example'] != null) {
                  buffer.write("    Example: \"${definition['example']}\"\n");
                }
              }
              buffer.write("\n");
            }
          }

          return buffer.toString();
        }

      case SelectionMenuType.wikipedia:
        if (result['source'] == 'gemini') {
          return "**Wikipedia Information**\n\n${result['data']}";
        } else {
          final data = result['data'];
          final title = data['title'] ?? widget.selectedText;
          final extract = data['extract'] ?? "No information found.";

          final buffer = StringBuffer("**Wikipedia: $title**\n\n$extract");

          if (data['content_urls'] != null &&
              data['content_urls']['desktop'] != null) {
            buffer.write(
                "\n\n[Read more on Wikipedia](${data['content_urls']['desktop']['page']})");
          }

          return buffer.toString();
        }

      case SelectionMenuType.generateImage:
        return "**Image Prompt Created**\n\n${result['imagePrompt']}";

      default:
        return "**Result**\n\n${result.toString()}";
    }
  }

  Future<void> _handleAskAi() async {
    await _executeTextSelectionOperation();
  }

  Future<void> _handleTranslate() async {
    await _executeTextSelectionOperation();
  }

  Future<void> _handleDictionary() async {
    await _executeTextSelectionOperation();
  }

  Future<void> _handleWikipedia() async {
    await _executeTextSelectionOperation();
  }

  Future<void> _handleGenerateImage() async {
    await _executeTextSelectionOperation();
  }

  // Helper methods for showing responses in chat
  void _showResponseInChat(String title, String content, String query) {
    if (widget.floatingChatKey?.currentState == null) return;

    // Show the floating chat
    widget.floatingChatKey!.currentState!.showChat();

    // Add messages directly without delay, which can cause context issues
    widget.floatingChatKey!.currentState!.addUserMessage(query);
    widget.floatingChatKey!.currentState!
        .addAiResponse("**$title**\n\n$content");
  }

  void _showError(String message) {
    // Don't use context here as it may be disposed
    print('Error in FullSelectionMenu: $message');

    if (widget.floatingChatKey?.currentState != null) {
      widget.floatingChatKey!.currentState!
          .addAiResponse("**Error**\n\n$message");
    }
  }
}

/// Helper class to hold book context information
class BookContext {
  final String title;
  final int currentPage;
  final int totalPages;

  const BookContext(
      {required this.title,
      required this.currentPage,
      required this.totalPages});
}

/// Helper class for chat responses
class ChatResponse {
  final String message;

  const ChatResponse({required this.message});
}

/// Extension for SelectionMenuType to provide default values
extension SelectionMenuTypeExtension on SelectionMenuType {
  String get name {
    switch (this) {
      case SelectionMenuType.askAi:
        return 'Ask AI';
      case SelectionMenuType.translate:
        return 'Translate';
      case SelectionMenuType.dictionary:
        return 'Dictionary';
      case SelectionMenuType.wikipedia:
        return 'Wikipedia';
      case SelectionMenuType.generateImage:
        return 'Generate Image';
      case SelectionMenuType.highlight:
        return 'Highlight';
      case SelectionMenuType.audio:
        return 'Audio';
    }
  }

  String get defaultBookTitle {
    switch (this) {
      case SelectionMenuType.askAi:
        return 'Ask AI';
      case SelectionMenuType.translate:
        return 'Translation';
      case SelectionMenuType.dictionary:
        return 'Dictionary';
      case SelectionMenuType.wikipedia:
        return 'Wikipedia';
      case SelectionMenuType.generateImage:
        return 'Image Generation';
      default:
        return 'Reading';
    }
  }
}
