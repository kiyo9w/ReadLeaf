import 'package:flutter/material.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';

class TypingIndicator extends StatefulWidget {
  final String characterName;

  const TypingIndicator({
    super.key,
    required this.characterName,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(
      3,
      (index) => TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(0),
          weight: 20,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.2, // Stagger the animations
            0.6 + index * 0.2,
            curve: Curves.linear,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveConstants.isTablet(context);
    final theme = Theme.of(context);
    final dotSize = isTablet ? 8.0 : 6.0;
    final spacing = isTablet ? 4.0 : 3.0;
    final fontSize = isTablet ? 15.0 : 14.0;
    final textColor = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
        Colors.grey.shade600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${widget.characterName} is thinking',
          style: TextStyle(
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: textColor,
          ),
        ),
        SizedBox(width: spacing * 1.5),
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -3 * _animations[index].value),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.only(right: index < 2 ? spacing : 0),
                  decoration: BoxDecoration(
                    color: theme.primaryColor
                        .withOpacity(0.4 + 0.6 * _animations[index].value),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
