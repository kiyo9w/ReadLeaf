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
        homeScreen?.generateNewAIMessage();
      }
    }
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isExpanded
          ? _expandedHeight
          : (_isTextExpanded ? _textExpandedHeight : _collapsedHeight),
      child: _isExpanded ? _buildExpandedView() : _buildCollapsedView(),
    );
  }

  Widget _buildCollapsedView() {
    return GestureDetector(
      onTap: _expand,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              characters[_selectedIndex].trait,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpandableDescription(
                text: characters[_selectedIndex].personality,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF424242),
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Character',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: _collapse,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
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

    return GestureDetector(
      onTap: () => _onCharacterTap(index),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[200]!,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  character.trait,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
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
    return Container(
      width: large ? 100 : 80,
      height: large ? 100 : 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: index == _selectedIndex ? Colors.blue : Colors.transparent,
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

  const ExpandableDescription({
    required this.text,
    required this.style,
    this.maxLines = 3,
    Key? key,
  }) : super(key: key);

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;
  bool _isTextExpanded = false;
  late TextPainter _textPainter;
  bool _hasOverflow = false;

  @override
  void initState() {
    super.initState();
    _checkTextOverflow();
  }

  void _checkTextOverflow() {
    _textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 300); // Approximate width

    _hasOverflow = _textPainter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final sliderState =
        context.findAncestorStateOfType<AiCharacterSliderState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TypingText(
          text: widget.text,
          style: widget.style,
          maxLines: _isExpanded ? null : widget.maxLines,
          typingSpeed: const Duration(milliseconds: 30),
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (_hasOverflow)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (sliderState != null) {
                  sliderState.setState(() {
                    sliderState._isTextExpanded = _isExpanded;
                  });
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
                  if (_isExpanded) ...[
                    Text(
                      'Show less',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                  ] else ...[
                    Text(
                      'Read more',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
