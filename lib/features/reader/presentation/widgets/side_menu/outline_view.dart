import 'package:flutter/material.dart';
import 'package:read_leaf/features/reader/domain/models/epub_models.dart';

class OutlineView extends StatelessWidget {
  const OutlineView({
    super.key,
    required this.outlines,
    required this.currentPage,
    required this.totalPages,
    required this.onItemTap,
  });

  final List<OutlineItem> outlines;
  final int currentPage;
  final int totalPages;
  final Function(OutlineItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    if (outlines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF6E6E73),
            ),
            const SizedBox(height: 16),
            Text(
              'No chapters found',
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
              'This book has no table of contents',
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: outlines.length,
      itemBuilder: (context, index) {
        final item = outlines[index];
        final isCurrentPage = item.pageNumber == currentPage;

        // Find the closest chapter to current page for highlighting
        final closestChapter =
            outlines.where((o) => o.pageNumber <= currentPage).lastOrNull;
        final shouldHighlight = closestChapter == item;

        return InkWell(
          onTap: () => onItemTap(item),
          child: Container(
            padding: EdgeInsets.only(
              left: 16.0 + (item.level * 20.0),
              right: 16.0,
              top: 10.0,
              bottom: 10.0,
            ),
            color: shouldHighlight
                ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF8F1F1))
                : Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF2F2F7)
                          : const Color(0xFF1C1C1E),
                      fontSize: item.level == 0 ? 14 : 13,
                      fontWeight:
                          item.level == 0 ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  'Page ${item.pageNumber}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6E6E73),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
