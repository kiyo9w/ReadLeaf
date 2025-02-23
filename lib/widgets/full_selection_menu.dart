import 'package:flutter/material.dart';
import 'package:read_leaf/widgets/floating_selection_menu.dart';

class FullSelectionMenu extends StatefulWidget {
  final String selectedText;
  final SelectionMenuType menuType;
  final VoidCallback? onDismiss;

  const FullSelectionMenu({
    super.key,
    required this.selectedText,
    required this.menuType,
    this.onDismiss,
  });

  @override
  State<FullSelectionMenu> createState() => _FullSelectionMenuState();
}

class _FullSelectionMenuState extends State<FullSelectionMenu> {
  late double _initialHeight;
  late double _maxHeight;
  bool _isExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupDimensions();
  }

  void _setupDimensions() {
    final screenHeight = MediaQuery.of(context).size.height;
    _initialHeight = screenHeight * 0.35; // 35% of screen height initially
    _maxHeight = screenHeight * 0.9; // 90% of screen height when expanded
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isExpanded ? _maxHeight : _initialHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFE5E5EA),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/icons/dictionary.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Dictionary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Selected text
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.selectedText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ),
                    // Dictionary options
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDictionaryOption('G', 'Google'),
                          _buildDictionaryOption('W', 'Wikiped'),
                          _buildDictionaryOption('M', 'Matriarch'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDictionaryOption(String letter, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
