import 'package:flutter/material.dart';
import 'package:migrated/models/ai_character.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/injection.dart';
import 'package:migrated/screens/create_character_screen.dart';
import 'package:migrated/screens/home_screen.dart';

class CharacterScreen extends StatefulWidget {
  final VoidCallback? onCharacterChanged;

  const CharacterScreen({
    super.key,
    this.onCharacterChanged,
  });

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AiCharacterService _characterService = getIt<AiCharacterService>();
  late AiCharacter? _selectedCharacter;
  bool _showVoices = false;

  // Categories for characters
  final List<String> _categories = [
    'All',
    'Study',
    'Fiction',
    'Research',
    'Custom'
  ];

  // Default voices
  final List<Map<String, String>> _voices = [
    {
      'name': 'French',
      'description': 'The real French guy',
      'color': '#B71C1C',
    },
    {
      'name': 'Bodyguard',
      'description': '👊 "My job is to protect you..." 👊 (Esp-Eng)',
      'color': '#827717',
    },
    {
      'name': 'Francis',
      'description': '',
      'color': '#E91E63',
    },
    {
      'name': 'Robot',
      'description': 'Just a robot :)',
      'color': '#FF9800',
    },
    {
      'name': 'Tala',
      'description': 'Always up for an adventure',
      'color': '#FF9800',
    },
    {
      'name': 'Southern',
      'description': 'Southern',
      'color': '#1B5E20',
    },
    {
      'name': 'Taz',
      'description': 'Australian dude',
      'color': '#00695C',
    },
    {
      'name': 'Bodhi',
      'description': 'A gentle breeze whispering through an ancient forest',
      'color': '#FF9800',
    },
    {
      'name': 'Woman',
      'description': 'Girl Voice by Venn',
      'color': '#BF360C',
    },
    {
      'name': 'Soft Bubbly',
      'description': 'Cheerful and sweet',
      'color': '#E91E63',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _selectedCharacter = _characterService.getSelectedCharacter();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectCharacter(AiCharacter character) {
    setState(() {
      _selectedCharacter = character;
    });
    _characterService.setSelectedCharacter(character);

    // Notify parent about character change
    widget.onCharacterChanged?.call();

    // Find and refresh HomeScreen
    final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
    homeScreen?.generateNewAIMessage();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _toggleView() {
    setState(() {
      _showVoices = !_showVoices;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              if (!_showVoices) _buildTabBar(theme),
              Expanded(
                child: _showVoices
                    ? _buildVoicesList(theme)
                    : TabBarView(
                        controller: _tabController,
                        children: _categories
                            .map((category) =>
                                _buildCategoryContent(category, theme))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: !_showVoices
            ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateCharacterScreen()),
                  );
                  if (result == true) {
                    // Character was created, refresh home screen
                    widget.onCharacterChanged?.call();
                    final homeScreen =
                        context.findAncestorStateOfType<HomeScreenState>();
                    homeScreen?.generateNewAIMessage();
                  }
                },
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showVoices ? 'Voices' : 'Choose Character',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleButton(theme),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      // TODO: Implement search
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_showVoices)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Recommended', true),
                    _buildFilterChip('Featured', false),
                    _buildFilterChip('Voices', false),
                    _buildFilterChip('Groups', false),
                    _buildFilterChip('Helper', false),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggleView,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showVoices ? Icons.person : Icons.record_voice_over,
                size: 20,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                _showVoices ? 'Characters' : 'Voices',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: null,
        backgroundColor: Colors.grey.withOpacity(0.1),
        selectedColor: Colors.blue.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: theme.primaryColor,
        unselectedLabelColor:
            theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: _categories.map((category) => Tab(text: category)).toList(),
      ),
    );
  }

  Widget _buildCategoryContent(String category, ThemeData theme) {
    final characters = _getCharactersByCategory(category);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeaturedCharacters(theme, characters),
          const SizedBox(height: 16),
          _buildAllCharacters(theme, characters),
          const SizedBox(height: 16),
          _buildRecentCharacters(theme, characters),
          const SizedBox(height: 80), // Add bottom padding for FAB
        ],
      ),
    );
  }

  Widget _buildVoicesList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _voices.length,
      itemBuilder: (context, index) {
        final voice = _voices[index];
        return _buildVoiceItem(voice, theme);
      },
    );
  }

  Widget _buildVoiceItem(Map<String, String> voice, ThemeData theme) {
    final color =
        Color(int.parse(voice['color']!.replaceFirst('#', 'FF'), radix: 16));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voice['name']!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (voice['description']!.isNotEmpty)
                  Text(
                    voice['description']!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<AiCharacter> _getCharactersByCategory(String category) {
    final allCharacters = _characterService.getAllCharacters();
    if (category == 'All') return allCharacters;
    return allCharacters
        .where((char) => char.categories.contains(category))
        .toList();
  }

  Widget _buildFeaturedCharacters(
      ThemeData theme, List<AiCharacter> characters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Featured Characters', theme),
        const SizedBox(height: 8),
        SizedBox(
          height: 140, // Reduced height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: characters.length.clamp(0, 5),
            itemBuilder: (context, index) => _buildFeaturedCharacterCard(
              characters[index],
              theme,
              isSelected: characters[index].name == _selectedCharacter?.name,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCharacters(ThemeData theme, List<AiCharacter> characters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('All Characters', theme),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: characters.length,
          itemBuilder: (context, index) => _buildCharacterListCard(
            characters[index],
            theme,
            isSelected: characters[index].name == _selectedCharacter?.name,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCharacters(ThemeData theme, List<AiCharacter> characters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Characters', theme),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: characters.length.clamp(0, 6),
          itemBuilder: (context, index) => _buildCharacterGridCard(
            characters[index],
            theme,
            isSelected: characters[index].name == _selectedCharacter?.name,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {
            // Handle see all tap
          },
          child: const Text('see all'),
        ),
      ],
    );
  }

  Widget _buildFeaturedCharacterCard(
    AiCharacter character,
    ThemeData theme, {
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: () => _selectCharacter(character),
      child: Container(
        width: 110, // Reduced width
        margin: const EdgeInsets.only(right: 8), // Reduced margin
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                character.imagePath,
                height: 85, // Reduced height
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13, // Smaller font
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.trait,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 11, // Smaller font
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterGridCard(
    AiCharacter character,
    ThemeData theme, {
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: () => _selectCharacter(character),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  character.imagePath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.trait,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterListCard(
    AiCharacter character,
    ThemeData theme, {
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: () => _selectCharacter(character),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: AssetImage(character.imagePath),
          ),
          title: Text(
            character.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            character.trait,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: theme.primaryColor)
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
