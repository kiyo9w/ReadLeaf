import 'package:flutter/material.dart';
import 'package:migrated/services/ai_character_service.dart';
import 'package:migrated/depeninject/injection.dart';

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
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final characterName = character?.name ?? 'Leafy AI';
    final characterImage =
        character?.imagePath ?? 'assets/images/leafy_icon.png';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          CustomPaint(
            painter: MessageBubblePainter(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 16,
            child: TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue reading...',
                    style: TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.brown,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8F5E9)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 12)
      ..lineTo(0, size.height - 12)
      ..arcToPoint(
        Offset(12, size.height),
        radius: const Radius.circular(12),
      )
      ..lineTo(size.width - 12, size.height)
      ..arcToPoint(
        Offset(size.width, size.height - 12),
        radius: const Radius.circular(12),
      )
      ..lineTo(size.width, 12)
      ..arcToPoint(
        Offset(size.width - 12, 0),
        radius: const Radius.circular(12),
      )
      ..lineTo(12, 0)
      ..arcToPoint(
        const Offset(0, 12),
        radius: const Radius.circular(12),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
