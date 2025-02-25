import 'package:flutter/material.dart';
import 'package:read_leaf/widgets/floating_selection_menu.dart';

class FullSelectionMenu extends StatefulWidget {
  final String selectedText;
  final SelectionMenuType menuType;
  final VoidCallback? onDismiss;

  const FullSelectionMenu({
    super.key,
    required this.selectedText,
    required this.menuType,
    this.onDismiss,
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
        break;
      case SelectionMenuType.dictionary:
        _customInstructionsController.text = 'Define this word';
        break;
      case SelectionMenuType.wikipedia:
        _customInstructionsController.text = 'Find information about this';
        break;
      case SelectionMenuType.generateImage:
        _customInstructionsController.text = 'Generate an image of this';
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
                              onPressed: _handleAction,
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
                              child: Row(
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
        widget.menuType == SelectionMenuType.generateImage;
  }

  Widget _buildOptionsContent() {
    if (widget.menuType == SelectionMenuType.translate) {
      return _buildLanguageOptions();
    } else if (widget.menuType == SelectionMenuType.generateImage) {
      return _buildImageStyleOptions();
    }
    return const SizedBox();
  }

  Widget _buildLanguageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildOptionChip('English', isDark, true),
        _buildOptionChip('Spanish', isDark, false),
        _buildOptionChip('French', isDark, false),
        _buildOptionChip('German', isDark, false),
        _buildOptionChip('Chinese', isDark, false),
        _buildOptionChip('Japanese', isDark, false),
        _buildOptionChip('Russian', isDark, false),
        _buildOptionChip('Arabic', isDark, false),
      ],
    );
  }

  Widget _buildImageStyleOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildOptionChip('Realistic', isDark, true),
        _buildOptionChip('Cartoon', isDark, false),
        _buildOptionChip('Anime', isDark, false),
        _buildOptionChip('Watercolor', isDark, false),
        _buildOptionChip('3D Render', isDark, false),
        _buildOptionChip('Sketch', isDark, false),
        _buildOptionChip('Pop Art', isDark, false),
        _buildOptionChip('Cyberpunk', isDark, false),
      ],
    );
  }

  Widget _buildOptionChip(String label, bool isDark, bool isSelected) {
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
      onSelected: (bool selected) {
        // Handle selection
      },
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

  void _handleAction() {
    // Process the action and then dismiss
    widget.onDismiss?.call();
  }
}
