import 'package:flutter/material.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';

class MinimizedCharacterSlider extends StatelessWidget {
  final VoidCallback onTap;
  
  const MinimizedCharacterSlider({
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.primaryColor,
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
                    character?.avatarImagePath ?? 'assets/images/ai_characters/amelia.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
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