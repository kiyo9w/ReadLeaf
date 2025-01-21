import 'package:flutter/material.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:migrated/widgets/typing_text.dart';
import 'package:migrated/themes/custom_theme_extension.dart';

class AIMessageCard extends StatelessWidget {
  final String message;
  final VoidCallback onContinue;

  const AIMessageCard({
    Key? key,
    required this.message,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final characterName = character?.name ?? 'Leafy AI';
    final characterImage =
        character?.imagePath ?? 'assets/images/leafy_icon.png';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          CustomPaint(
            painter: MessageBubblePainter(
              color: customTheme?.aiMessageBackground ??
                  const Color.fromARGB(255, 21, 3, 44),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        characterImage,
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$characterName has been waiting:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: customTheme?.aiMessageText ?? Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TypingText(
                    text: message,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: customTheme?.aiMessageText ?? Colors.white,
                    ),
                    typingSpeed: const Duration(milliseconds: 30),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onContinue,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continue reading...',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          color: theme.primaryColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubblePainter extends CustomPainter {
  final Color color;

  MessageBubblePainter({this.color = const Color.fromARGB(255, 21, 3, 44)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
