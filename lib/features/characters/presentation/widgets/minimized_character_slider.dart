import 'package:flutter/material.dart';
import 'package:read_leaf/features/characters/data/ai_character_service.dart';
import 'package:read_leaf/injection/injection.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

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

  // Helper method to determine how to load the image based on the path
  Widget _buildAvatarImage(String imagePath) {
    // Handle network URLs
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading avatar image: $url - $error');
          return Image.asset(
            'assets/images/ai_characters/amelia.png',
            fit: BoxFit.cover,
          );
        },
        httpHeaders: const {
          'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*;q=0.8',
          'User-Agent': 'ReadLeaf/1.0',
        },
      );
    }

    // Handle asset images
    else if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset avatar image: $error');
          return Image.asset(
            'assets/images/ai_characters/amelia.png',
            fit: BoxFit.cover,
          );
        },
      );
    }

    // Handle local file paths
    else {
      try {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading file avatar image: $error');
            return Image.asset(
              'assets/images/ai_characters/amelia.png',
              fit: BoxFit.cover,
            );
          },
        );
      } catch (e) {
        debugPrint('Error creating file image: $e');
        // Fallback to a default avatar
        return Image.asset(
          'assets/images/ai_characters/amelia.png',
          fit: BoxFit.cover,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final theme = Theme.of(context);
    final isTablet = ResponsiveConstants.isTablet(context);

    // Calculate sizes based on tablet or mobile and position (appbar or not)
    final double avatarSize =
        widget.inAppBar ? (isTablet ? 50.0 : 44.0) : (isTablet ? 68.0 : 58.0);

    final double pulseSize =
        widget.inAppBar ? (isTablet ? 52.0 : 46.0) : (isTablet ? 70.0 : 60.0);

    final double iconSize =
        widget.inAppBar ? (isTablet ? 18.0 : 16.0) : (isTablet ? 20.0 : 16.0);

    final double borderWidth = isTablet ? 2.5 : 2.0;
    final double padding =
        widget.inAppBar ? (isTablet ? 10.0 : 8.0) : (isTablet ? 5.0 : 5.0);

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
                      width: pulseSize,
                      height: pulseSize,
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
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor,
                      width: borderWidth,
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
                    child: character?.avatarImagePath != null
                        ? _buildAvatarImage(character!.avatarImagePath)
                        : Image.asset(
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
                    padding: EdgeInsets.all(padding),
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
                      size: iconSize,
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
