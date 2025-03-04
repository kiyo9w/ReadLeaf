import 'package:flutter/material.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/injection/injection.dart';

class MinimizedCharacterSlider extends StatefulWidget {
  final VoidCallback onTap;
  final bool inAppBar;

  const MinimizedCharacterSlider({
    required this.onTap,
    this.inAppBar = false,
    super.key,
  });

  @override
  State<MinimizedCharacterSlider> createState() =>
      _MinimizedCharacterSliderState();
}

class _MinimizedCharacterSliderState extends State<MinimizedCharacterSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: widget.inAppBar ? 0 : 8,
          horizontal: widget.inAppBar ? 8 : 0,
        ),
        child: Center(
          child: Stack(
            children: [
              // Animated glow effect
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.inAppBar ? 46 : 60,
                      height: widget.inAppBar ? 46 : 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.primaryColor.withOpacity(0.7),
                            theme.primaryColor.withOpacity(0.0),
                          ],
                          radius: 0.7,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Character avatar
              Hero(
                tag: 'character_avatar_${character?.name ?? "default"}',
                child: Container(
                  width: widget.inAppBar ? 44 : 58,
                  height: widget.inAppBar ? 44 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      character?.avatarImagePath ??
                          'assets/images/ai_characters/amelia.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              if (!widget.inAppBar)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor,
                          Color.lerp(theme.primaryColor, Colors.purple, 0.3) ??
                              theme.primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.expand_less,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
