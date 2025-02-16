import 'package:flutter/material.dart';
import 'package:read_leaf/constants/responsive_constants.dart';

enum SelectionMenuType {
  askAi(
      icon: Icons.chat_bubble_outline,
      label: 'Ask AI',
      color: Color(0xFF007AFF)),
  highlight(
      icon: Icons.brush_outlined, label: 'Highlight', color: Color(0xFFFFB800)),
  translate(
      icon: Icons.translate_outlined,
      label: 'Translate',
      color: Color(0xFF34C759)),
  audio(
      icon: Icons.volume_up_outlined, label: 'Audio', color: Color(0xFFFF2D55));

  final IconData icon;
  final String label;
  final Color color;

  const SelectionMenuType({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class FloatingSelectionMenu extends StatefulWidget {
  final String selectedText;
  final Function(SelectionMenuType, String) onMenuSelected;
  final VoidCallback? onDismiss;

  const FloatingSelectionMenu({
    Key? key,
    required this.selectedText,
    required this.onMenuSelected,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<FloatingSelectionMenu> createState() => _FloatingSelectionMenuState();
}

class _FloatingSelectionMenuState extends State<FloatingSelectionMenu> {
  late PageController _pageController;
  int _currentPage = 0;
  final double _menuHeight = 56.0;
  final double _menuWidth = 160.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.8,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismiss area
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              color: Colors.transparent,
            ),
          ),
          // Menu
          Center(
            child: Container(
              height: _menuHeight,
              width: _menuWidth * 1.2,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: SelectionMenuType.values.length,
                itemBuilder: (context, index) {
                  final menuType = SelectionMenuType.values[index];
                  final isActive = index == _currentPage;

                  return GestureDetector(
                    onTap: () =>
                        widget.onMenuSelected(menuType, widget.selectedText),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isActive ? 1.0 : 0.5,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              menuType.icon,
                              color: menuType.color,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              menuType.label,
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Page indicators
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                SelectionMenuType.values.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black87.withOpacity(0.3),
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
