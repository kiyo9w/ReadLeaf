import 'package:flutter/material.dart';

class FloatingChatHead extends StatefulWidget {
  final VoidCallback onTap;
  final String avatarImagePath;

  const FloatingChatHead({
    super.key,
    required this.onTap,
    required this.avatarImagePath,
  });

  @override
  State<FloatingChatHead> createState() => _FloatingChatHeadState();
}

class _FloatingChatHeadState extends State<FloatingChatHead> {
  Offset position = const Offset(20, 100); // Initial position
  bool isDragging = false;

  void _updatePosition(DragUpdateDetails details) {
    setState(() {
      position = Offset(
        position.dx - details.delta.dx,
        position.dy - details.delta.dy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: _updatePosition,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Container(
              width: 60,
              height: 60,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(
                  widget.avatarImagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
