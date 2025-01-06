import 'package:flutter/material.dart';

class AiCharacter {
  final String name;
  final String imagePath;
  final String personality;

  const AiCharacter({
    required this.name,
    required this.imagePath,
    required this.personality,
  });
}

class AiCharacterSlider extends StatefulWidget {
  const AiCharacterSlider({super.key});

  @override
  State<AiCharacterSlider> createState() => _AiCharacterSliderState();
}

class _AiCharacterSliderState extends State<AiCharacterSlider> {
  bool _isExpanded = false;
  int _selectedIndex = 2; // Default to the middle character

  final List<AiCharacter> characters = const [
    AiCharacter(
      name: 'Thomas',
      imagePath: 'assets/images/ai_characters/professor.png',
      personality:
          'A wise and knowledgeable professor who explains things in detail',
    ),
    AiCharacter(
      name: 'Noah',
      imagePath: 'assets/images/ai_characters/student.png',
      personality:
          'A friendly and curious student who likes to learn and share',
    ),
    AiCharacter(
      name: 'Amelia',
      imagePath: 'assets/images/ai_characters/librarian.png',
      personality:
          'A helpful librarian who loves books and organizing information',
    ),
    AiCharacter(
      name: 'Violetta',
      imagePath: 'assets/images/ai_characters/artist.png',
      personality: 'A creative artist who sees beauty in everything',
    ),
    AiCharacter(
      name: 'Christine',
      imagePath: 'assets/images/ai_characters/scientist.png',
      personality: 'A precise scientist who analyzes everything methodically',
    ),
  ];

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isExpanded = true;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isExpanded = false;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isExpanded) return;

    final delta = details.primaryDelta ?? 0;
    if (delta.abs() > 10) {
      final direction = delta > 0 ? 1 : -1;
      setState(() {
        _selectedIndex =
            (_selectedIndex - direction).clamp(0, characters.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
          children: [
            if (_isExpanded) ...[
              // Background overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100]?.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Character indicators
              Positioned(
                bottom: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    characters.length,
                    (index) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _selectedIndex
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Character images
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isExpanded)
                  ...List.generate(
                    characters.length,
                    (index) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity:
                          _isExpanded && index != _selectedIndex ? 0.5 : 1.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale:
                            _isExpanded && index == _selectedIndex ? 1.1 : 0.8,
                        child: Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: index == _selectedIndex
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              characters[index].imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        characters[_selectedIndex].imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
            // Character name and hint
            Positioned(
              bottom: _isExpanded ? 28 : 8,
              child: Column(
                children: [
                  Text(
                    characters[_selectedIndex].name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isExpanded)
                    Text(
                      'Hold and swipe to change character',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
