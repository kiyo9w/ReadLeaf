import 'package:flutter/material.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/injection/injection.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/core/constants/ui_constants.dart';
import 'package:read_leaf/widgets/typing_text.dart';
import 'package:read_leaf/features/library/presentation/screens/home_screen.dart';
import 'dart:async';
import 'dart:ui';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:read_leaf/core/themes/custom_theme_extension.dart';
import 'package:read_leaf/features/characters/presentation/widgets/typing_indicator.dart';
import 'package:provider/provider.dart';
import 'package:read_leaf/core/providers/settings_provider.dart';

/// A custom painter that draws a subtle grid pattern
class GridPatternPainter extends CustomPainter {
  final Color lineColor;
  final double lineWidth;
  final double spacing;

  GridPatternPainter({
    required this.lineColor,
    required this.lineWidth,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AiCharacterSlider extends StatefulWidget {
  static final globalKey = GlobalKey<_AiCharacterSliderState>();
  final VoidCallback? onCharacterSelected;
  final VoidCallback? onMinimize;
  final String? aiMessage;
  final VoidCallback? onContinueReading;
  final VoidCallback? onRemove;
  final Function(String)? onUpdatePrompt;
  final bool isGeneratingMessage;

  const AiCharacterSlider({
    super.key,
    this.onCharacterSelected,
    this.onMinimize,
    this.aiMessage,
    this.onContinueReading,
    this.onRemove,
    this.onUpdatePrompt,
    this.isGeneratingMessage = false,
  });

  @override
  State<AiCharacterSlider> createState() => _AiCharacterSliderState();
}

class _AiCharacterSliderState extends State<AiCharacterSlider>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isDescriptionVisible = false;
  bool _isSettingsOpen = false;
  late int _selectedIndex;
  late List<AiCharacter> characters = [];
  bool _isLoading = true;
  late ScrollController _scrollController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  OverlayEntry? _settingsOverlay;

  // Distance in pixels between each character's "center"
  final double _spacing = UIConstants.characterSpacing;

  late final AiCharacterService _characterService;

  @override
  void initState() {
    super.initState();
    _characterService = getIt<AiCharacterService>();
    _loadCharacters();

    // Subscribe to character updates
    _characterService.onCharacterUpdate.listen((_) {
      if (mounted) {
        _loadCharacters();
      }
    });

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    );

    _scrollController = ScrollController();

    // Initialize the animation with a small non-zero value to prevent assertion errors
    _expandController.value = 0.01;
  }

  @override
  void dispose() {
    _removeSettingsOverlay();
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

  Future<void> _loadCharacters() async {
    try {
      final loadedCharacters = await _characterService.getAllCharacters();
      final selectedCharacter = _characterService.getSelectedCharacter();

      if (!mounted) return;

      setState(() {
        characters = loadedCharacters;
        _selectedIndex = characters
            .indexWhere((char) => char.name == selectedCharacter?.name);
        if (_selectedIndex == -1 && characters.isNotEmpty) {
          _selectedIndex =
              characters.indexWhere((char) => char.name == 'Amelia');
          if (_selectedIndex == -1) {
            _selectedIndex = 0;
          }
        }
        _isLoading = false;
      });

      // Scroll to selected character after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedCharacter(animate: false);
      });
    } catch (e) {
      print('Error loading characters: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        characters = [];
        _selectedIndex = -1;
      });
    }
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

  void _showPromptDialog(BuildContext context, String characterName) {
    final controller = TextEditingController(text: "");
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: theme.cardColor,
        title: Text(
          'Customize $characterName\'s Reminder',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22.0 : 20.0,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customize how $characterName reminds you to continue reading.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isTablet ? 16.0 : 14.0,
              ),
            ),
            SizedBox(height: isTablet ? 20.0 : 16.0),
            TextField(
              controller: controller,
              maxLines: 4,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: isTablet ? 16.0 : 14.0,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surface.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.primaryColor,
                    width: 2,
                  ),
                ),
                hintText: 'Enter custom prompt...',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: isTablet ? 16.0 : 14.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodyMedium?.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20.0 : 16.0,
                vertical: isTablet ? 12.0 : 10.0,
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: isTablet ? 16.0 : 14.0,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              widget.onUpdatePrompt?.call(controller.text);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20.0 : 16.0,
                vertical: isTablet ? 12.0 : 10.0,
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: isTablet ? 16.0 : 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        contentPadding: EdgeInsets.only(
          top: isTablet ? 20.0 : 16.0,
          left: isTablet ? 24.0 : 20.0,
          right: isTablet ? 24.0 : 20.0,
          bottom: isTablet ? 8.0 : 4.0,
        ),
        actionsPadding: EdgeInsets.only(
          left: isTablet ? 24.0 : 20.0,
          right: isTablet ? 24.0 : 20.0,
          bottom: isTablet ? 20.0 : 16.0,
        ),
      ),
    );
  }

  void _toggleSettings() {
    if (_isSettingsOpen) {
      _removeSettingsOverlay();
    } else {
      _showSettingsOverlay();
    }
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
    });
  }

  void _showSettingsOverlay() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final settingsButtonPosition = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Calculate position for the settings menu
    final character = characters[_selectedIndex];
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    _settingsOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible full-screen button to detect taps outside the menu
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleSettings,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          Positioned(
            top: settingsButtonPosition.dy + 70, // Same position as before
            right: isTablet ? 20.0 : 16.0,
            child: Material(
              color: Colors.transparent,
              child: _buildSettingsMenu(theme, character.name),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_settingsOverlay!);
  }

  void _removeSettingsOverlay() {
    _settingsOverlay?.remove();
    _settingsOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: ResponsiveConstants.isTablet(context) ? 160.0 : 140.0,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (characters.isEmpty) {
      return SizedBox(
        height: ResponsiveConstants.isTablet(context) ? 160.0 : 140.0,
        child: const Center(child: Text('No characters available')),
      );
    }

    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final avatarSize = ResponsiveConstants.isTablet(context) ? 80.0 : 70.0;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveConstants.isTablet(context) ? 24.0 : 16.0,
          vertical: ResponsiveConstants.isTablet(context) ? 12.0 : 8.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, _isExpanded ? -0.1 : 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: _isExpanded
            ? _buildExpandedView()
            : _buildCollapsedView(theme, customTheme, avatarSize),
      ),
    );
  }

  Widget _buildCollapsedView(
      ThemeData theme, CustomThemeExtension? customTheme, double avatarSize) {
    final character = characters[_selectedIndex];
    final messageTextColor = customTheme?.aiMessageText ?? Colors.white;
    final gradientStart = customTheme?.aiMessageBackground ??
        const Color.fromARGB(255, 33, 10, 60);
    final gradientEnd = HSLColor.fromColor(gradientStart)
        .withLightness((HSLColor.fromColor(gradientStart).lightness + 0.07)
            .clamp(0.0, 1.0))
        .toColor();
    final isTablet = ResponsiveConstants.isTablet(context);

    return AnimatedContainer(
      key: const ValueKey('collapsed_view'),
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
          stops: const [0.3, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 1,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: GridPatternPainter(
                  lineColor: Colors.white,
                  lineWidth: 0.2,
                  spacing: isTablet ? 18.0 : 15.0,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header section with character info
              Padding(
                padding: EdgeInsets.fromLTRB(
                    isTablet ? 20.0 : 16.0,
                    isTablet ? 20.0 : 16.0,
                    isTablet ? 20.0 : 16.0,
                    isTablet ? 10.0 : 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Character avatar with info button
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _expand,
                          child: Hero(
                            tag: 'character_avatar_${character.name}',
                            child: Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.primaryColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.1),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  character.avatarImagePath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDescriptionVisible = !_isDescriptionVisible;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isDescriptionVisible
                                    ? Icons.visibility_off
                                    : Icons.info_outline,
                                color: Colors.white,
                                size: isTablet ? 16.0 : 14.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: isTablet ? 20.0 : 16.0),

                    // Character name and trait
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            character.name,
                            style: TextStyle(
                              fontSize: isTablet ? 24.0 : 22.0,
                              fontWeight: FontWeight.bold,
                              color: messageTextColor,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 8.0 : 6.0),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12.0 : 10.0,
                              vertical: isTablet ? 4.0 : 3.0,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor.withOpacity(0.2),
                                  theme.primaryColor.withOpacity(0.3),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              character.trait,
                              style: TextStyle(
                                fontSize: isTablet ? 15.0 : 14.0,
                                color: messageTextColor,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.keyboard_arrow_up,
                          onTap: widget.onMinimize,
                          tooltip: 'Hide',
                          color: messageTextColor,
                        ),
                        _buildActionButton(
                          icon: Icons.swap_horiz_rounded,
                          onTap: _expand,
                          tooltip: 'Change character',
                          color: messageTextColor,
                        ),
                        _buildActionButton(
                          icon: Icons.settings,
                          onTap: _toggleSettings,
                          tooltip: 'Settings',
                          color: messageTextColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Character description (conditional)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isDescriptionVisible ? null : 0,
                curve: Curves.easeInOut,
                child: _isDescriptionVisible
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                isTablet ? 20.0 : 16.0,
                                0,
                                isTablet ? 20.0 : 16.0,
                                isTablet ? 10.0 : 8.0),
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TypingText(
                                text: character.personality,
                                style: TextStyle(
                                  fontSize: isTablet ? 14.0 : 13.0,
                                  height: 1.4,
                                  color: messageTextColor,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: isTablet ? 4 : 3,
                                typingSpeed: const Duration(milliseconds: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // AI Message or Typing Indicator
              Padding(
                padding: EdgeInsets.fromLTRB(isTablet ? 20.0 : 16.0, 0,
                    isTablet ? 20.0 : 16.0, isTablet ? 6.0 : 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.aiMessage != null &&
                        widget.aiMessage!.isNotEmpty)
                      TypingText(
                        text: widget.aiMessage!,
                        style: TextStyle(
                          fontSize: isTablet ? 16.0 : 15.0,
                          height: 1.5,
                          color: messageTextColor,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        typingSpeed: const Duration(milliseconds: 30),
                      )
                    else if (widget.isGeneratingMessage)
                      _buildThinkingIndicator(
                          theme, character.name, messageTextColor, isTablet),

                    if (widget.aiMessage != null &&
                        widget.aiMessage!.isNotEmpty)
                      SizedBox(height: isTablet ? 12.0 : 8.0), // Reduced space

                    if (widget.aiMessage != null &&
                        widget.aiMessage!.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildContinueReadingButton(theme),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(
      ThemeData theme, String characterName, Color textColor, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 12.0 : 8.0),
      child: TypingIndicator(
        characterName: characterName,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
    required Color color,
  }) {
    final isTablet = ResponsiveConstants.isTablet(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 10.0 : 8.0),
            margin: EdgeInsets.symmetric(horizontal: isTablet ? 3.0 : 2.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: isTablet ? 24.0 : 22.0,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(ThemeData theme, String characterName) {
    final isTablet = ResponsiveConstants.isTablet(context);
    // Get the settings provider to check the actual reminders state
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final bool remindersActive = settingsProvider.remindersEnabled;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: isTablet ? 280.0 : 250.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor.withOpacity(0.85),
                  theme.cardColor.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingsItem(
                  icon: Icons.edit,
                  title: 'Change how $characterName reminds me',
                  onTap: () {
                    _toggleSettings();
                    _showPromptDialog(context, characterName);
                  },
                  theme: theme,
                ),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withOpacity(0.2),
                  indent: 16,
                  endIndent: 16,
                ),
                _buildSettingsItem(
                  icon: remindersActive
                      ? Icons.notifications_off
                      : Icons.notifications_active,
                  title: remindersActive
                      ? 'Turn off reminders'
                      : 'Turn on reminders',
                  onTap: () {
                    _toggleSettings();
                    // Toggle the reminders setting in the provider
                    settingsProvider.toggleReminders(!remindersActive);

                    // If we're turning reminders on, we need to generate a new message
                    if (!remindersActive) {
                      final homeScreen =
                          context.findAncestorStateOfType<HomeScreenState>();
                      if (homeScreen != null) {
                        Future.microtask(() {
                          homeScreen.generateNewAIMessage();
                        });
                      }
                    } else {
                      // If we're turning reminders off, call the onRemove callback
                      widget.onRemove?.call();
                    }
                  },
                  theme: theme,
                  iconColor: remindersActive
                      ? Colors.red.shade400
                      : Colors.green.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
    Color? iconColor,
  }) {
    final isTablet = ResponsiveConstants.isTablet(context);

    return InkWell(
      onTap: onTap,
      splashColor: theme.primaryColor.withOpacity(0.1),
      highlightColor: theme.primaryColor.withOpacity(0.05),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20.0 : 16.0,
          vertical: isTablet ? 16.0 : 12.0,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: isTablet ? 22.0 : 20.0,
                color: iconColor ?? theme.primaryColor,
              ),
            ),
            SizedBox(width: isTablet ? 20.0 : 16.0),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: isTablet ? 15.0 : 14.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReadingButton(ThemeData theme) {
    final isTablet = ResponsiveConstants.isTablet(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            Color.lerp(theme.primaryColor, Colors.purple, 0.3) ??
                theme.primaryColor,
            Color.lerp(theme.primaryColor, Colors.blue, 0.1) ??
                theme.primaryColor,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onContinueReading,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24.0 : 20.0,
              vertical: isTablet ? 14.0 : 12.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue reading',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16.0 : 15.0,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: isTablet ? 10.0 : 8.0),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: isTablet ? 20.0 : 18.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    return Container(
      key: const ValueKey('expanded_view'),
      padding: EdgeInsets.only(bottom: isTablet ? 16.0 : 12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and close button
          Container(
            padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.15),
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Character',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: ResponsiveConstants.getTitleFontSize(context),
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _collapse,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 10.0 : 8.0),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        color: theme.iconTheme.color,
                        size: ResponsiveConstants.getIconSize(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Character selector - improved with better padding
          SizedBox(
            height: isTablet ? 240.0 : 220.0,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20.0 : 16.0,
                  vertical: isTablet ? 16.0 : 12.0),
              itemCount: characters.length,
              itemBuilder: (context, index) => _buildCharacterItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterItem(int index) {
    final character = characters[index];
    final isSelected = index == _selectedIndex;
    final isCustom = character.tags.contains('Custom');
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isTablet ? 160.0 : 140.0,
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 12.0 : 10.0),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor.withOpacity(0.15),
                  theme.primaryColor.withOpacity(0.05),
                ],
                stops: const [0.3, 1.0],
              )
            : null,
        color: isSelected ? null : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? theme.primaryColor : theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.25)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 2),
          ),
          if (isSelected)
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCharacterTap(index),
          borderRadius: BorderRadius.circular(17),
          splashColor: theme.primaryColor.withOpacity(0.15),
          highlightColor: theme.primaryColor.withOpacity(0.1),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(
                          begin: 0.95,
                          end: isSelected ? 1.05 : 0.95,
                        ),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Hero(
                          tag: isSelected
                              ? 'character_avatar_${character.name}'
                              : 'character_avatar_inactive_${character.name}',
                          child: Container(
                            width: isTablet ? 90.0 : 82.0,
                            height: isTablet ? 90.0 : 82.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.primaryColor
                                    : Colors.transparent,
                                width: isSelected ? 3 : 0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? theme.primaryColor.withOpacity(0.5)
                                      : Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                character.avatarImagePath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isTablet ? 14.0 : 12.0),
                    Text(
                      character.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.primaryColor
                            : theme.textTheme.bodyLarge?.color,
                        fontSize: isTablet ? 18.0 : 16.0,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: isTablet ? 8.0 : 6.0),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12.0 : 10.0,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor.withOpacity(0.25)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor.withOpacity(0.3)
                              : theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        character.trait,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.textTheme.bodySmall?.color,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          letterSpacing: 0.2,
                          fontSize: isTablet ? 13.0 : 12.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCustom)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _deleteCharacter(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: isTablet ? 18.0 : 16.0,
                      ),
                    ),
                  ),
                ),
              if (isSelected)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: isTablet ? 30.0 : 26.0,
                      height: isTablet ? 30.0 : 26.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            Color.lerp(
                                    theme.primaryColor, Colors.purple, 0.3) ??
                                theme.primaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: isTablet ? 18.0 : 16.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCharacterTap(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _characterService.setSelectedCharacter(characters[index]);

      // Only generate new message if the character actually changed
      if (context.mounted) {
        final homeScreen = context.findAncestorStateOfType<HomeScreenState>();
        if (homeScreen != null) {
          // Use microtask to ensure state updates are complete
          Future.microtask(() {
            homeScreen.generateNewAIMessage();
          });
        }
      }
    }
    _collapse();
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
      await _characterService.deleteCharacter(characters[index].name);

      // Update UI
      setState(() {
        characters.removeAt(index);
        if (_selectedIndex >= characters.length) {
          _selectedIndex = characters.length - 1;
        }
      });
    }
  }

  /// Expand into the row of characters.
  void _expand() {
    setState(() {
      _isExpanded = true;
      _isSettingsOpen = false;
    });
  }

  /// Collapse back to a single avatar.
  void _collapse() {
    setState(() {
      _isExpanded = false;
      _isSettingsOpen = false;
    });
    _removeSettingsOverlay();
  }
}
