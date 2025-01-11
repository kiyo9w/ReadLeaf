import 'package:flutter/material.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/constants/ui_constants.dart';
import 'package:migrated/widgets/typing_text.dart';
import 'package:migrated/screens/home_screen.dart';

class AiCharacterSlider extends StatefulWidget {
  const AiCharacterSlider({Key? key}) : super(key: key);

  @override
  State<AiCharacterSlider> createState() => _AiCharacterSliderState();
}

class _AiCharacterSliderState extends State<AiCharacterSlider> {
  bool _isExpanded = false;
  late int _selectedIndex;
  final List<AiCharacter> characters = AiCharacterService.defaultCharacters;

  // Tracks how far we've dragged left/right in expanded mode
  double _dragDx = 0.0;

  // Distance in pixels between each character's "center"
  final double _spacing = UIConstants.characterSpacing;

  late final AiCharacterService _characterService;

  /// Expand into the row of characters.
  void _expand() {
    setState(() {
      _isExpanded = true;
      _dragDx = 0.0; // reset any leftover drag
    });
  }

  /// Collapse back to a single avatar.
  void _collapseAndSnapToClosest() {
    final double stepsDragged = -_dragDx / _spacing;
    int newIndex = _selectedIndex + stepsDragged.round();
    newIndex = newIndex.clamp(0, characters.length - 1);

    if (newIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newIndex;
        _dragDx = 0.0;
        _isExpanded = false;
      });

      // Update the selected character in the service
      _characterService.setSelectedCharacter(characters[_selectedIndex]);

      // Trigger a new AI message in the HomeScreen
      if (context.mounted) {
        final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
        homeScreen?.generateNewAIMessage();
      }
    } else {
      setState(() {
        _dragDx = 0.0;
        _isExpanded = false;
      });
    }
  }

  /// The X-position of character i in the expanded state,
  /// relative to the center of the container.
  /// i.e. if i == _selectedIndex, its base is 0 plus any drag offset.
  double _xPositionForIndex(int i) {
    // If i = _selectedIndex, base offset is (i - i) * spacing = 0
    // If i < _selectedIndex, negative offset => left side
    // If i > _selectedIndex, positive offset => right side
    // Then we add _dragDx (the user’s current drag).
    return (i - _selectedIndex) * _spacing + _dragDx;
  }

  @override
  void initState() {
    super.initState();
    _characterService = getIt<AiCharacterService>();

    // Get the selected character from the service
    final selectedCharacter = _characterService.getSelectedCharacter();
    _selectedIndex =
        characters.indexWhere((char) => char.name == selectedCharacter?.name);
    if (_selectedIndex == -1) {
      _selectedIndex = 2; // Default to Amelia if not found
    }
  }

  @override
  Widget build(BuildContext context) {
    // ------------------
    // Collapsed State
    // ------------------
    if (!_isExpanded) {
      return GestureDetector(
        onLongPress: _expand,
        onHorizontalDragStart: (_) => _expand(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                characters[_selectedIndex].name,
                style: UIConstants.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: UIConstants.smallPadding),
              Container(
                width: UIConstants.characterAvatarSize,
                height: UIConstants.characterAvatarSize,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(
                    characters[_selectedIndex].imagePath,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ------------------
    // Expanded State
    // ------------------
    return GestureDetector(
      // We track pan/drag manually to shift the entire row
      onPanUpdate: (details) {
        setState(() {
          _dragDx += details.delta.dx;
        });
      },
      onPanEnd: (details) {
        // Once user lets go, we snap to whichever character is nearest center.
        _collapseAndSnapToClosest();
      },
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: MediaQuery.of(context).size.width * 0.9, // some margin
          height: 200, // Increased height to accommodate personality text
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // (Optional) background overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50]?.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Row of characters (actually a Stack, each child positioned).
              for (int i = 0; i < characters.length; i++)
                _buildCharacter(i, context),
              // Example instructions at bottom
              Positioned(
                top: 10,
                child: Text(
                  'Drag left/right and release',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacter(int i, BuildContext context) {
    // Calculate the center position of the screen
    final screenCenter = MediaQuery.of(context).size.width / 2;
    // Calculate the total width needed for all characters
    final totalWidth = characters.length * _spacing;
    // Calculate the starting x position to center all characters
    final startX = screenCenter - (totalWidth / 2);
    // Calculate the final position for this character
    final xPos = startX + (i * _spacing) + _dragDx;

    final bool isSelected = (i == _selectedIndex);

    return Positioned(
      top: 30,
      left: xPos - 50, // Center the character by offsetting half its width
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Container(
                width: 100,
                height: 100,
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      characters[i].imagePath,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Container(
                width: 200,
                transform: Matrix4.translationValues(
                    -50, 0, 0), // Center the text box relative to the character
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TypingText(
                  text: characters[i].personality,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    height: 1.4,
                  ),
                  startTyping: isSelected,
                  typingSpeed: const Duration(milliseconds: 30),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
