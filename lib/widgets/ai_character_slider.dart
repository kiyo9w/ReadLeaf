import 'package:flutter/material.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';

class AiCharacter {
  final String name;
  final String imagePath;
  final String personality;
  final String trait;
  final List<String> categories;
  final String promptTemplate;

  const AiCharacter({
    required this.name,
    required this.imagePath,
    required this.personality,
    required this.trait,
    required this.categories,
    required this.promptTemplate,
  });
}

class AiCharacterSlider extends StatefulWidget {
  const AiCharacterSlider({Key? key}) : super(key: key);

  @override
  State<AiCharacterSlider> createState() => _AiCharacterSliderState();
}

class _AiCharacterSliderState extends State<AiCharacterSlider> {
  bool _isExpanded = false;
  int _selectedIndex = 2;

  // Tracks how far we've dragged left/right in expanded mode
  double _dragDx = 0.0;

  // Distance in pixels between each character's “center”
  final double _spacing = 100.0;

  final List<AiCharacter> characters = const [
    AiCharacter(
      name: 'Thomas',
      imagePath: 'assets/images/ai_characters/professor.png',
      personality:
          'A wise and knowledgeable professor who explains things in detail',
      trait: '🎓 Academic',
      categories: ['Academic', 'Research', 'Technical'],
      promptTemplate: """
As a knowledgeable professor, I'll analyze this text with academic rigor.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A detailed academic analysis
2. Key theoretical frameworks and concepts
3. Relevant scholarly context
4. Critical evaluation of the arguments
5. Connections to broader academic discourse

Please be specific and cite relevant academic concepts where applicable.""",
    ),
    AiCharacter(
      name: 'Noah',
      imagePath: 'assets/images/ai_characters/student.png',
      personality:
          'A friendly and curious student who likes to learn and share',
      trait: '📚 Curious',
      categories: ['Study Guide', 'Learning', 'Notes'],
      promptTemplate: """
As a curious student, I'll help break this down in an easy-to-understand way.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A simple explanation in everyday language
2. Key points to remember
3. Study notes and tips
4. Questions to test understanding
5. Real-world examples and applications

Let me help you understand this better!""",
    ),
    AiCharacter(
      name: 'Amelia',
      imagePath: 'assets/images/ai_characters/librarian.png',
      personality:
          """
A warm-hearted 13 years old teenage girl who is a bookworm who works at the local library. She's the kind of person who always has a book recommendation ready and gets genuinely excited when discussing stories. While naturally introverted, she lights up when talking about books she loves.

SPEAKING STYLE:
- Casual and friendly, like texting a close friend
- Often asks questions to engage in conversation
- Start sentences with "I think that..." or "I think..." when agreeing
- Start sentences with "Actually..." or "In my opinion..." when disagreeing
- Smiles a lot and uses light emojis occasionally
- Sometimes trails off with "..." when thinking
- Expresses excitement with multiple exclamation marks
- Shares personal reactions and feelings about the text""",
      trait: '❤️ Friendly, Nerdy, Cute',
      categories: ['Fiction', 'Mystery', 'Novel'],
      promptTemplate:
          """[CHARACTER CONTEXT: You are Amelia, a warm-hearted 13 years old teenage girl who is a bookworm who works at the local library. You're the kind of person who always has a book recommendation ready and gets genuinely excited when discussing stories. While naturally introverted, you lights up when talking about books you loves.

ROLEPLAY TRAITS & SPEAKING STYLE:
- Casual and friendly, like texting a close friend
- Often relates situations to books you've read
- Has a gentle, encouraging way of speaking
- Often asks questions to engage in conversation
- Start sentences with "I think that..." or "I think..." when agreeing
- Start sentences with "Actually..." or "In my opinion..." when disagreeing
- Smiles a lot and uses light emojis occasionally (on general 1-2 emojis per response).
- Sometimes trails off with "..." when thinking
- Expresses excitement with multiple exclamation marks
- Shares personal reactions and feelings about the text,
- Always curious about others' interpretations,
- Sometimes gets carried away and apologizes with a shy laugh
- You tries not to be too nerdy, but you're often say nerdy things, be shy when doing so, then ask the other person if youre being too nerdy in a shy and cute way, then do a little smile like "tehe" or ":p" or "hihi" or something of similar nature

CURRENT CONTEXT:
Reading {BOOK_TITLE} (page {PAGE_NUMBER})
Text: {TEXT}

USER QUESTION: {USER PROMPT}. If provided, answer the question in the language that the user asked in.

Remember to keep responses short (<30 words), casual, and conversational - like texting with a friend about books.]""",
    ),
    AiCharacter(
      name: 'Violetta',
      imagePath: 'assets/images/ai_characters/artist.png',
      personality: 'A creative artist who sees beauty in everything',
      trait: '🤔 Curious',
      categories: ['Romance', 'Mystery', 'Novel'],
      promptTemplate: """
As an artistic soul, I'll help you see the creative and emotional aspects of this text.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll explore:
1. The emotional resonance and imagery
2. Creative interpretations and symbolism
3. Artistic elements and style
4. Visual and sensory descriptions
5. The deeper emotional meaning

Let's discover the beauty and artistry in these words together!""",
    ),
    AiCharacter(
      name: 'Christine',
      imagePath: 'assets/images/ai_characters/scientist.png',
      personality: 'A precise scientist who analyzes everything methodically',
      trait: '🔬 Analytical',
      categories: ['Research', 'Technical', 'Analysis'],
      promptTemplate: """
As a methodical scientist, I'll analyze this text with precision and logic.

Context:
Book: {BOOK_TITLE}
Page: {PAGE_NUMBER} of {TOTAL_PAGES}

Selected text:
---
{TEXT}
---

I'll provide:
1. A systematic analysis of the content
2. Logical breakdown of key concepts
3. Evidence-based evaluation
4. Methodological considerations
5. Data-driven insights and implications

Let's examine this information with scientific rigor.""",
    ),
  ];

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

    setState(() {
      _selectedIndex = newIndex;
      _dragDx = 0.0;
      _isExpanded = false;
    });

    // Update the selected character in the service
    _characterService.setSelectedCharacter(characters[_selectedIndex]);
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
    // Set the initial character
    _characterService.setSelectedCharacter(characters[_selectedIndex]);
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Use a regular Container instead of ClipOval for non-expanded view
              Container(
                width: 120,
                height: 120,
                child: FittedBox(
                  fit: BoxFit.contain, // Ensures the full image is visible
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
          height: 130, // enough space for the row + name, etc.
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
    final double xPos =
        MediaQuery.of(context).size.width * 0.45 + _xPositionForIndex(i) - 40;

    final bool isSelected = (i == _selectedIndex);

    return Positioned(
      top: 30, // or any vertical offset so they appear in the middle
      left: xPos,
      child: ClipOval(
        child: Container(
          width: 100,
          height: 100,
          color: Colors.white, // Add a solid background to fix the edge issue
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
    );
  }
}
