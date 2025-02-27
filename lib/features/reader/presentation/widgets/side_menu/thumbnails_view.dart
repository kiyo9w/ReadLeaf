import 'package:flutter/material.dart';

class ThumbnailsView extends StatelessWidget {
  const ThumbnailsView({
    Key? key,
    required this.totalPages,
    required this.currentPage,
    required this.onPageSelected,
    required this.getThumbnail,
  }) : super(key: key);

  final int totalPages;
  final int currentPage;
  final Function(int) onPageSelected;
  final Widget Function(int) getThumbnail;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF6E6E73),
            ),
            const SizedBox(height: 16),
            Text(
              'No pages available',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF1C1C1E),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load page thumbnails',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF6E6E73),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.8,
      ),
      itemCount: totalPages,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isCurrentPage = pageNumber == currentPage;

        return GestureDetector(
          onTap: () => onPageSelected(pageNumber),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isCurrentPage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFE5E5EA),
                      width: isCurrentPage ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1C1C1E)
                        : Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7.0),
                    child: getThumbnail(pageNumber),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Page $pageNumber',
                style: TextStyle(
                  color: isCurrentPage
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF666666),
                  fontWeight:
                      isCurrentPage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
