import 'dart:math';
import 'package:flutter/material.dart';
import 'package:read_leaf/features/auth/presentation/widgets/auth_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final Duration? autoDismissAfter;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.autoDismissAfter,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flyAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Flying path animation
    _flyAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 40.0,
      ),
    ]).animate(_controller);

    // Scale animation
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 50.0,
      ),
    ]).animate(_controller);

    // Rotation animation
    _rotateAnimation = Tween<double>(
      begin: -0.1,
      end: 0.1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Fade animation for auto-dismiss
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0),
      ),
    );

    // Set up auto-dismiss if specified
    if (widget.autoDismissAfter != null) {
      Future.delayed(widget.autoDismissAfter!).then((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Check your email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: size.height * 0.3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated path
                    AnimatedBuilder(
                      animation: _flyAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(size.width * 0.8, size.height * 0.2),
                          painter: PathPainter(
                            progress: _flyAnimation.value,
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        );
                      },
                    ),
                    // Animated paper airplane
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(_controller.value * 2 * pi) * 20,
                            sin(_controller.value * 2 * pi) * 10,
                          ),
                          child: Transform.rotate(
                            angle: _rotateAnimation.value,
                            child: Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Icon(
                                Icons.send,
                                size: 64,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Please check your email and click the verification link to continue.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (widget.autoDismissAfter == null) ...[
                AuthButton(
                  text: 'Open Email App',
                  onPressed: () {
                    // TODO: Implement email app opening
                  },
                  isOutlined: true,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Sign In'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final double progress;
  final Color color;

  PathPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.5,
        0,
        size.width,
        size.height * 0.5,
      );

    final pathMetrics = path.computeMetrics().first;
    final pathSegment = pathMetrics.extractPath(
      0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(pathSegment, paint);
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
