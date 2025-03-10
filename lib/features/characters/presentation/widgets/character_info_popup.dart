import 'package:flutter/material.dart';
import 'package:read_leaf/features/characters/domain/models/ai_character.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';
import 'package:read_leaf/core/themes/custom_theme_extension.dart';
import 'dart:ui';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class CharacterInfoPopup extends StatelessWidget {
  final AiCharacter character;
  final VoidCallback onClose;
  final VoidCallback? onSelect;
  final Widget Function(String, {double? width, double? height, BoxFit fit})?
      buildAvatarImage;

  const CharacterInfoPopup({
    super.key,
    required this.character,
    required this.onClose,
    this.onSelect,
    this.buildAvatarImage,
  });

  Widget _buildImage(String imagePath,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (buildAvatarImage != null) {
      return buildAvatarImage!(imagePath,
          width: width, height: height, fit: fit);
    }

    // Improved image handling - similar to CharacterScreen
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint(
              'CharacterInfoPopup - Error loading avatar: $url - $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.grey,
              ),
            ),
          );
        },
        memCacheHeight: 300,
        memCacheWidth: 300,
        fadeInDuration: const Duration(milliseconds: 200),
        httpHeaders: const {
          'Accept': 'image/png,image/jpeg,image/webp,image/*,*/*;q=0.8',
          'User-Agent': 'ReadLeaf/1.0',
          'Cache-Control': 'max-age=31536000',
        },
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.person,
              size: 40,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  ImageProvider _buildBackgroundImage(String imagePath, BuildContext context) {
    // For network images, we need a workaround since DecorationImage expects ImageProvider
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return NetworkImage(imagePath);
    }
    // For asset images
    else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    }
    // For local files (fallback to asset if any issues)
    else {
      try {
        return FileImage(File(imagePath));
      } catch (e) {
        debugPrint('Error creating file image: $e');
        return const AssetImage(
            'assets/images/ai_characters/default_avatar.png');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final isTablet = ResponsiveConstants.isTablet(context);
    final size = MediaQuery.of(context).size;

    // Get screen width to determine popup width
    final popupWidth = size.width * (isTablet ? 0.6 : 0.85);
    final popupHeight = size.height * 0.7;

    final headerHeight = popupHeight * 0.25;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: popupWidth,
            height: popupHeight,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with close button
                Stack(
                  children: [
                    // Profile header background and image
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Stack(
                        children: [
                          // Use a solid color fallback in case the background image fails
                          Container(
                            height: headerHeight,
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                          // Blurred background using character avatar
                          Container(
                            height: headerHeight,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: _safeBackgroundImage(
                                    character.avatarImagePath, context),
                                fit: BoxFit.cover,
                                opacity: 0.6,
                              ),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                color: theme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                          ),
                          // Simplified gradient overlay
                          Container(
                            height: headerHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  theme.primaryColor.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          // Avatar
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildImage(character.avatarImagePath),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Character name and stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Character name
                      Text(
                        character.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 28 : 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      // Character trait/tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          character.trait,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: isTablet ? 18 : 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Character stats (Tags) - limit to 7
                      _buildLimitedTagsWrap(character.tags, theme, isTablet),
                    ],
                  ),
                ),

                // Character info in a scrollable area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoSection(
                            'Summary', character.summary, theme, isTablet),
                        _buildInfoSection('Personality', character.personality,
                            theme, isTablet),
                        _buildInfoSection(
                            'Scenario', character.scenario, theme, isTablet),
                        _buildInfoSection('Greeting', character.greetingMessage,
                            theme, isTablet),
                        if (character.exampleMessages.isNotEmpty)
                          _buildInfoSection(
                              'Example Messages',
                              character.exampleMessages.join('\n\n'),
                              theme,
                              isTablet),
                        if (character.systemPrompt != null &&
                            character.systemPrompt!.isNotEmpty)
                          _buildInfoSection('System Prompt',
                              character.systemPrompt!, theme, isTablet),
                        _buildInfoSection(
                            'Creator', character.creator, theme, isTablet),
                        _buildInfoSection(
                            'Created',
                            character.createdAt.toString().split('.')[0],
                            theme,
                            isTablet),
                      ],
                    ),
                  ),
                ),

                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Select Character',
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Creates a widget with up to 7 tags and a "+x" chip if more
  Widget _buildLimitedTagsWrap(
      List<String> tags, ThemeData theme, bool isTablet) {
    const maxVisibleTags = 7;

    // Prepare the list of tags to display
    final displayTags = <Widget>[];

    // Add up to maxVisibleTags tags
    for (int i = 0; i < tags.length && i < maxVisibleTags; i++) {
      displayTags.add(
        Chip(
          label: Text(
            tags[i],
            style: TextStyle(
              fontSize: isTablet ? 14 : 13,
            ),
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
          labelStyle: theme.textTheme.bodyMedium,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Add a count chip if there are more tags
    if (tags.length > maxVisibleTags) {
      final extraCount = tags.length - maxVisibleTags;
      displayTags.add(
        Chip(
          label: Text(
            "+ $extraCount",
            style: TextStyle(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: displayTags,
    );
  }

  // Safe method to get background image that won't crash
  ImageProvider _safeBackgroundImage(String imagePath, BuildContext context) {
    try {
      return _buildBackgroundImage(imagePath, context);
    } catch (e) {
      debugPrint('Error creating background image: $e');
      return const AssetImage('assets/images/ai_characters/default_avatar.png');
    }
  }

  Widget _buildInfoSection(
      String title, String content, ThemeData theme, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
              fontSize: isTablet ? 20 : 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontSize: isTablet ? 16 : 15,
            ),
          ),
        ],
      ),
    );
  }
}
