import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // Build robust image with caching
  Widget _buildAvatar() {
    final imagePath = widget.avatarImagePath;

    // For network images
    if (imagePath.startsWith('http') ||
        imagePath.startsWith('https') ||
        imagePath.contains('avatars.charhub.io')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, error, url) {
          debugPrint('Error loading avatar in FloatingChatHead: $url - $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.person,
              size: 30,
              color: Colors.grey,
            ),
          );
        },
        fadeInDuration: const Duration(milliseconds: 0),
        memCacheHeight: 120,
        memCacheWidth: 120,
        cacheKey: 'floating_head_${widget.avatarImagePath}',
        useOldImageOnUrlChange: true,
      );
    }

    // For asset/local images
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      cacheHeight: 120,
      cacheWidth: 120,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Error loading avatar asset in FloatingChatHead: $error');
        return Container(
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.person,
            size: 30,
            color: Colors.grey,
          ),
        );
      },
    );
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
                child: _buildAvatar(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
