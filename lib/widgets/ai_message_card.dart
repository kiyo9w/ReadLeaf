import 'package:flutter/material.dart';
import 'package:read_leaf/services/ai_character_service.dart';
import 'package:read_leaf/injection.dart';
import 'package:read_leaf/widgets/typing_text.dart';
import 'package:read_leaf/themes/custom_theme_extension.dart';

class AIMessageCard extends StatelessWidget {
  final String message;
  final VoidCallback onContinue;
  final bool skipAnimation;
  final VoidCallback? onRemove;
  final Function(String)? onUpdatePrompt;

  const AIMessageCard({
    Key? key,
    required this.message,
    required this.onContinue,
    this.skipAnimation = false,
    this.onRemove,
    this.onUpdatePrompt,
  }) : super(key: key);

  void _showPromptDialog(BuildContext context, String characterName) {
    final controller = TextEditingController(
      text: "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Customize $characterName\'s Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customize how $characterName reminds you to continue reading.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter custom prompt...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onUpdatePrompt?.call(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final character = getIt<AiCharacterService>().getSelectedCharacter();
    final characterName = character?.name ?? 'Leafy AI';
    final characterImage =
        character?.avatarImagePath ?? 'assets/images/app_logo/logo_nobg.jpeg';

    // Sanitize the message to prevent UTF-16 errors
    final sanitizedMessage = message.replaceAll(RegExp(r'[^\x00-\x7F]+'), '');

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
                      Expanded(
                        child: Text(
                          '$characterName has been waiting:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: customTheme?.aiMessageText ?? Colors.white,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: customTheme?.aiMessageText ?? Colors.white,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'customize',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 20),
                                const SizedBox(width: 8),
                                Text('Change how $characterName reminds me'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.notifications_off, size: 20),
                                SizedBox(width: 8),
                                Text('Turn off'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'customize') {
                            _showPromptDialog(context, characterName);
                          } else if (value == 'remove') {
                            onRemove?.call();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TypingText(
                    text: sanitizedMessage,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: customTheme?.aiMessageText ?? Colors.white,
                    ),
                    typingSpeed: const Duration(milliseconds: 30),
                    skipAnimation: skipAnimation,
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
