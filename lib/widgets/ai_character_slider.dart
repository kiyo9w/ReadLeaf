import 'package:flutter/material.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/constants/ui_constants.dart';
import 'package:migrated/widgets/typing_text.dart';
import 'package:migrated/screens/home_screen.dart';

class AiCharacterSlider extends StatefulWidget {
  static final globalKey = GlobalKey<AiCharacterSliderState>();

  AiCharacterSlider({Key? key}) : super(key: key ?? globalKey);

  @override
  State<AiCharacterSlider> createState() => AiCharacterSliderState();
}

class AiCharacterSliderState extends State<AiCharacterSlider>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isTextExpanded = false;
  late int _selectedIndex;
  late List<AiCharacter> characters;
  late ScrollController _scrollController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // Distance in pixels between each character's "center"
  final double _spacing = UIConstants.characterSpacing;
  final double _expandedHeight = 280.0;
  final double _collapsedHeight = 330.0;
  final double _textExpandedHeight = 401.0;

  late final AiCharacterService _characterService;

  @override
  void initState() {
    super.initState();
    _characterService = getIt<AiCharacterService>();
    _loadCharacters();

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedCharacter(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _scrollToSelectedCharacter({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final targetOffset = _selectedIndex * _spacing;
    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  void _loadCharacters() {
    setState(() {
      characters = _characterService.getAllCharacters();
      final selectedCharacter = _characterService.getSelectedCharacter();
      _selectedIndex =
          characters.indexWhere((char) => char.name == selectedCharacter?.name);
      if (_selectedIndex == -1) {
        _selectedIndex = 2; // Default to Amelia if not found
      }
    });
  }

  // Add a new character to the slider
  void addCharacter(AiCharacter character) {
    setState(() {
      characters.add(character);
      _selectedIndex = characters.length - 1;
    });
  }

  // Force a refresh of the character list
  void refreshCharacters() {
    _loadCharacters();
  }

  @override
  void didUpdateWidget(AiCharacterSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload characters when widget updates
    _loadCharacters();
  }

  /// Expand into the row of characters.
  void _expand() {
    setState(() {
      _isExpanded = true;
    });
    _expandController.forward();
  }

  /// Collapse back to a single avatar.
  void _collapse() {
    setState(() {
      _isExpanded = false;
    });
    _expandController.reverse();
  }

  void _onCharacterTap(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _characterService.setSelectedCharacter(characters[_selectedIndex]);

      // Trigger a new AI message in the HomeScreen
      if (context.mounted) {
        final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
        if (homeScreen != null) {
          // Ensure the character switch is complete before generating new message
          Future.microtask(() {
            homeScreen.generateNewAIMessage();
          });
        }
      }
    }
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded
          ? _expandedHeight
          : (_isTextExpanded ? _textExpandedHeight : _collapsedHeight),
      onEnd: () {
        // Only allow description expansion after container animation is complete
        if (_isTextExpanded) {
          setState(() {
            _allowDescriptionExpansion = true;
          });
        }
      },
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: _isExpanded
                ? _expandedHeight
                : (_isTextExpanded ? _textExpandedHeight : _collapsedHeight),
          ),
          child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
        ),
      ),
    );
  }

  bool _allowDescriptionExpansion = false;

  void setTextExpanded(bool expanded) {
    if (!expanded) {
      // When collapsing, wait for the description to finish collapsing before shrinking the parent
      setState(() {
        _isTextExpanded = false;
        _allowDescriptionExpansion = false;
      });
    } else {
      setState(() {
        _isTextExpanded = true;
      });
    }
  }

  Widget _buildCollapsedView() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _expand,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _buildCharacterAvatar(_selectedIndex, large: true),
            ),
            const SizedBox(height: 12),
            Text(
              characters[_selectedIndex].name,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              characters[_selectedIndex].trait,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpandableDescription(
                    text: characters[_selectedIndex].personality,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 3,
                    maxWidth: constraints.maxWidth - 24,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Choose Character',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _collapse,
                  icon: Icon(Icons.close, color: theme.iconTheme.color),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: characters.length,
              itemBuilder: (context, index) => _buildCharacterCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(int index) {
    final character = characters[index];
    final isSelected = index == _selectedIndex;
    final isCustom = character.categories.contains('Custom');
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _onCharacterTap(index),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: _buildCharacterAvatar(index),
                ),
                const SizedBox(height: 8),
                Text(
                  character.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  character.trait,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (isCustom)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _deleteCharacter(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterAvatar(int index, {bool large = false}) {
    final theme = Theme.of(context);
    return Container(
      width: large ? 100 : 80,
      height: large ? 100 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              index == _selectedIndex ? theme.primaryColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          characters[index].imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _deleteCharacter(int index) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content:
            Text('Are you sure you want to delete ${characters[index].name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      // Delete from service
      await _characterService.deleteCharacter(characters[index]);

      // Update UI
      setState(() {
        characters.removeAt(index);
        if (_selectedIndex >= characters.length) {
          _selectedIndex = characters.length - 1;
        }
      });
    }
  }
}

class ExpandableDescription extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final double maxWidth;

  const ExpandableDescription({
    required this.text,
    required this.style,
    required this.maxWidth,
    this.maxLines = 3,
    Key? key,
  }) : super(key: key);

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;
  late TextPainter _textPainter;
  bool _hasOverflow = false;
  late int _actualLineCount;

  @override
  void initState() {
    super.initState();
    _measureText();
  }

  @override
  void didUpdateWidget(ExpandableDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.style != widget.style) {
      _measureText();
    }
  }

  void _measureText() {
    _textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1000, // High number to measure actual lines
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: widget.maxWidth);

    // Calculate actual number of lines
    List<LineMetrics> lines = _textPainter.computeLineMetrics();
    _actualLineCount = lines.length;

    // Check if text overflows the collapsed state
    _textPainter.maxLines = widget.maxLines;
    _textPainter.layout(maxWidth: widget.maxWidth);
    _hasOverflow = _textPainter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final sliderState =
        context.findAncestorStateOfType<AiCharacterSliderState>();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      onEnd: () {
        // After description collapses, notify parent to shrink if needed
        if (!_isExpanded) {
          sliderState?.setTextExpanded(false);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypingText(
            text: widget.text,
            style: widget.style,
            maxLines: _isExpanded ? _actualLineCount : widget.maxLines,
            typingSpeed: const Duration(milliseconds: 30),
            overflow: TextOverflow.ellipsis,
          ),
          if (_hasOverflow)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                  if (_isExpanded) {
                    sliderState?.setTextExpanded(true);
                    sliderState?.setState(() {
                      sliderState._allowDescriptionExpansion = true;
                    });
                  } else {
                    // Only collapse the description first, parent will be notified via onEnd
                    _isExpanded = false;
                  }
                });
              },
              child: Container(
                width: double.infinity,
                height: 36,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _isExpanded
                        ? [Colors.transparent, Colors.grey.withOpacity(0.1)]
                        : [Colors.grey.withOpacity(0.1), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded ? 'Show less' : 'Read more',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
