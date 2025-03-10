import 'package:flutter/material.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/injection/injection.dart';
import 'package:read_leaf/features/characters/presentation/screens/create_character_screen.dart';
import 'package:read_leaf/features/characters/presentation/screens/import_character_screen.dart';
import 'package:read_leaf/features/library/presentation/screens/home_screen.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:read_leaf/nav_screen.dart';
import 'package:read_leaf/features/library/presentation/widgets/refresh_animation.dart';
import 'package:flutter/rendering.dart';
import 'package:read_leaf/features/characters/presentation/widgets/character_info_popup.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

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
  final ScrollController _mainScrollController = ScrollController();
  final Map<String, ScrollController> _tabScrollControllers = {};
  bool _isScrollingDown = false;

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
    for (var category in _categories) {
      _tabScrollControllers[category] = ScrollController()
        ..addListener(() => _scrollListener(_tabScrollControllers[category]!));
    }
    _selectedCharacter = _characterService.getSelectedCharacter();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    for (var controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _scrollListener(ScrollController controller) {
    if (!controller.hasClients) return;

    if (controller.position.userScrollDirection == ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        _isScrollingDown = true;
        NavScreen.globalKey.currentState?.hideNavBar(true);
      }
    }

    if (controller.position.userScrollDirection == ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.hideNavBar(false);
      }
    }
  }

  void _selectCharacter(AiCharacter character) {
    if (!mounted) return;

    setState(() {
      _selectedCharacter = character;
    });
    _characterService.setSelectedCharacter(character);

    // Notify parent about character change
    widget.onCharacterChanged?.call();

    // Find and refresh HomeScreen
    if (mounted) {
      final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
      homeScreen?.generateNewAIMessage();
    }

    if (mounted && Navigator.canPop(context)) {
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            if (!_showVoices) _buildTabBar(theme),
            Expanded(
              child: _showVoices
                  ? PullToRefreshAnimation(
                      onRefresh: () async {
                        await Future.delayed(const Duration(seconds: 2));
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: ListView.builder(
                        controller: _mainScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _voices.length,
                        itemBuilder: (context, index) {
                          final voice = _voices[index];
                          return _buildVoiceItem(voice, theme);
                        },
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: _categories.map((category) {
                        return PullToRefreshAnimation(
                          onRefresh: () async {
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          child: SingleChildScrollView(
                            controller: _tabScrollControllers[category],
                            child: _buildCategoryContent(category, theme),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_showVoices
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Create button
                Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      splashColor: theme.primaryColor.withOpacity(0.1),
                      highlightColor: theme.primaryColor.withOpacity(0.05),
                      onTap: () async {
                        if (!mounted) return;

                        final RenderBox button =
                            context.findRenderObject() as RenderBox;
                        final Offset buttonPosition =
                            button.localToGlobal(Offset.zero);

                        final dialogResult = await showDialog(
                          context: context,
                          barrierColor: Colors.transparent,
                          builder: (BuildContext dialogContext) {
                            return Stack(
                              children: [
                                Positioned(
                                  right: 16,
                                  bottom: buttonPosition.dy + 130,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(16)),
                                            splashColor: theme.primaryColor
                                                .withOpacity(0.1),
                                            highlightColor: theme.primaryColor
                                                .withOpacity(0.05),
                                            onTap: () async {
                                              Navigator.pop(dialogContext);
                                              if (!mounted) return;

                                              final result =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        const CreateCharacterScreen()),
                                              );
                                              if (result == true && mounted) {
                                                widget.onCharacterChanged
                                                    ?.call();
                                                final homeScreen = context
                                                    .findAncestorStateOfType<
                                                        HomeScreenState>();
                                                homeScreen
                                                    ?.generateNewAIMessage();
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.person_add,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Character',
                                                    style: TextStyle(
                                                      color: theme.colorScheme
                                                          .onSurface,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Divider(
                                              height: 1,
                                              color: theme.dividerColor),
                                          InkWell(
                                            splashColor: theme.primaryColor
                                                .withOpacity(0.1),
                                            highlightColor: theme.primaryColor
                                                .withOpacity(0.05),
                                            onTap: () async {
                                              Navigator.pop(dialogContext);
                                              if (!mounted) return;

                                              final result = await FilePicker
                                                  .platform
                                                  .pickFiles(
                                                type: FileType.custom,
                                                allowedExtensions: ['json'],
                                              );

                                              if (result != null && mounted) {
                                                final file = result.files.first;
                                                if (!mounted) return;

                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ImportCharacterScreen(
                                                      filePath: file.path!,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.file_upload,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Import',
                                                    style: TextStyle(
                                                      color: theme.colorScheme
                                                          .onSurface,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Divider(
                                              height: 1,
                                              color: theme.dividerColor),
                                          InkWell(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    bottom:
                                                        Radius.circular(16)),
                                            splashColor: theme.primaryColor
                                                .withOpacity(0.1),
                                            highlightColor: theme.primaryColor
                                                .withOpacity(0.05),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _toggleView();
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.record_voice_over,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Voice',
                                                    style: TextStyle(
                                                      color: theme.colorScheme
                                                          .onSurface,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: theme.colorScheme.onSurface),
                            const SizedBox(width: 8),
                            Text(
                              'Create',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
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
    return FutureBuilder<List<AiCharacter>>(
      future: _loadCharactersByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading characters: ${snapshot.error}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          );
        }

        final characters = snapshot.data ?? [];

        if (characters.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No characters found in this category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeaturedCharacters(theme, characters.take(5).toList()),
              const SizedBox(height: 16),
              _buildAllCharacters(theme, characters),
              const SizedBox(height: 16),
              _buildRecentCharacters(theme, characters.take(6).toList()),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoiceItem(Map<String, String> voice, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              Color(int.parse(voice['color']!.replaceAll('#', '0xFF'))),
          child: Text(
            voice['name']![0],
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          voice['name']!,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: voice['description']!.isNotEmpty
            ? Text(
                voice['description']!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              )
            : null,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  List<AiCharacter> _getCharactersByCategory(String category) {
    final allCharacters = _characterService.getCharactersSync();
    if (category == 'All') return allCharacters;
    return allCharacters.where((char) => char.tags.contains(category)).toList();
  }

  Future<List<AiCharacter>> _loadCharactersByCategory(String category) async {
    try {
      return await _characterService.getCharactersByCategory(category);
    } catch (e) {
      // Fall back to local filtering if server request fails
      return _getCharactersByCategory(category);
    }
  }

  Widget _buildFeaturedCharacters(
      ThemeData theme, List<AiCharacter> characters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Featured Characters', theme),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
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
          child: const Text(
            'See All',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      onLongPress: () => _showCharacterInfoPopup(context, character),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
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
              child: _buildAvatarImage(
                character.avatarImagePath,
                height: 85,
                width: double.infinity,
                memCacheHeight: 200,
                memCacheWidth: 200,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    character.summary.replaceAll('\n', ' '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 11,
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
      onLongPress: () => _showCharacterInfoPopup(context, character),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.transparent,
                child: ClipOval(
                  child: _buildAvatarImage(
                    character.avatarImagePath,
                    fit: BoxFit.cover,
                    memCacheWidth: 112,
                    memCacheHeight: 112,
                  ),
                ),
              ),
            ),
            title: Text(
              character.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Container(
              margin: const EdgeInsets.only(top: 4),
              child: Text(
                character.summary.replaceAll('\n', ' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: theme.primaryColor)
                : const Icon(Icons.chevron_right),
          ),
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
      onLongPress: () => _showCharacterInfoPopup(context, character),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.primaryColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _buildAvatarImage(
                  character.avatarImagePath,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
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
                    character.summary.replaceAll('\n', ' '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      height: 1.2,
                    ),
                    maxLines: 2,
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

  // Helper method to extract trait from character tags
  String _getCharacterTrait(AiCharacter character) {
    // If character has a single tag, use it as trait
    if (character.tags.isNotEmpty) {
      return character.tags.first;
    }

    // Otherwise use the first sentence/part of the summary
    final summary = character.summary;
    if (summary.contains('.')) {
      return summary.split('.').first.trim();
    }

    if (summary.contains('\n')) {
      return summary.split('\n').first.trim();
    }

    // Fallback to a portion of the summary
    if (summary.length > 30) {
      return '${summary.substring(0, 30).trim()}...';
    }

    return summary.isEmpty ? 'Character' : summary;
  }

  // Helper method to determine how to load the image based on the path
  Widget _buildAvatarImage(
    String imagePath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    bool useCircleAvatar = false,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    // Handle network URLs
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading avatar image: $url - $error');
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.person,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        },
        memCacheHeight: memCacheHeight ?? (height?.toInt() ?? 200),
        memCacheWidth: memCacheWidth ?? (width?.toInt() ?? 200),
        fadeInDuration: const Duration(milliseconds: 200),
        httpHeaders: const {
          'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*;q=0.8',
          'User-Agent': 'ReadLeaf/1.0',
          'Cache-Control': 'max-age=31536000',
        },
      );
    }

    // Handle asset images
    else if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset avatar image: $error');
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.person,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        },
      );
    }

    // Handle local file paths
    else {
      try {
        return Image.file(
          File(imagePath),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading file avatar image: $error');
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          },
        );
      } catch (e) {
        debugPrint('Error creating file image: $e');
        // Fallback to a default avatar
        return Image.asset(
          'assets/images/ai_characters/default_avatar.png',
          width: width,
          height: height,
          fit: fit,
        );
      }
    }
  }

  void _showCharacterInfoPopup(BuildContext context, AiCharacter character) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => CharacterInfoPopup(
        character: character,
        onClose: () => Navigator.of(context).pop(),
        onSelect: () {
          Navigator.of(context).pop();
          _selectCharacter(character);
        },
      ),
    );
  }
}
