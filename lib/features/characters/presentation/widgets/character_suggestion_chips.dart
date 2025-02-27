import 'dart:async';
import 'package:flutter/material.dart';

/// A new multi-category trait selection widget.
/// Each category is displayed in a tab, and within each tab, we show chips
/// for unselected, selected, and related traits.
class MultiCategorySuggestionChips extends StatefulWidget {
  final Map<String, List<String>> categoryTraits;
  // e.g. {
  //   'Personality (Positive)': [...],
  //   'Personality (Neutral)': [...],
  //   'Physical': [...],
  //   'Speech Style': [...],
  //   ...
  // }

  final Function(String) onChipSelected;
  final Set<String> selectedTraits;
  final Map<String, List<String>> relatedTraits;
  final bool enableSearch;

  const MultiCategorySuggestionChips({
    super.key,
    required this.categoryTraits,
    required this.onChipSelected,
    required this.selectedTraits,
    required this.relatedTraits,
    this.enableSearch = true,
  });

  @override
  _MultiCategorySuggestionChipsState createState() =>
      _MultiCategorySuggestionChipsState();
}

class _MultiCategorySuggestionChipsState
    extends State<MultiCategorySuggestionChips>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = '';
  Timer? _debounce;
  Map<String, List<String>> filteredCategoryTraits = {};

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.categoryTraits.keys.length, vsync: this);
    widget.categoryTraits.forEach((category, traits) {
      filteredCategoryTraits[category] = List.from(traits);
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchQuery = query;
        widget.categoryTraits.forEach((category, traits) {
          filteredCategoryTraits[category] = traits
              .where((t) => t.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = widget.categoryTraits.keys.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.enableSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search traits...',
                prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.primaryColor,
          unselectedLabelColor:
              theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: categories.map((cat) => Tab(text: cat)).toList(),
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: categories.map((category) {
              final traits = filteredCategoryTraits[category] ?? [];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: _buildChipsForCategory(category, traits),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChipsForCategory(String category, List<String> traits) {
    List<Widget> chipWidgets = [];

    // 1. Add selected traits in the order they were selected
    for (var trait in widget.selectedTraits) {
      // Ensure trait is in this category
      if (traits.contains(trait)) {
        chipWidgets.add(SelectedChip(
          key: ValueKey('selected_$trait'),
          trait: trait,
          onDeselected: widget.onChipSelected,
        ));
        // Also show related if any
        if (widget.relatedTraits.containsKey(trait)) {
          for (var related in widget.relatedTraits[trait]!) {
            if (!widget.selectedTraits.contains(related)) {
              chipWidgets.add(RelatedChip(
                key: ValueKey('related_${trait}_$related'),
                trait: related,
                onSelected: widget.onChipSelected,
              ));
            }
          }
        }
      }
    }

    // 2. Then add unselected traits
    for (var trait in traits) {
      if (!widget.selectedTraits.contains(trait)) {
        chipWidgets.add(PrimaryChip(
          key: ValueKey('primary_$trait'),
          trait: trait,
          onSelected: widget.onChipSelected,
        ));
      }
    }

    return chipWidgets;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}

class PrimaryChip extends StatefulWidget {
  final String trait;
  final Function(String) onSelected;
  const PrimaryChip({super.key, required this.trait, required this.onSelected});

  @override
  State<PrimaryChip> createState() => _PrimaryChipState();
}

class _PrimaryChipState extends State<PrimaryChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => widget.onSelected(widget.trait),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark ? Colors.white70 : theme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : theme.shadowColor.withOpacity(_isPressed ? 0.05 : 0.1),
              blurRadius: _isPressed ? 2 : 4,
              offset: Offset(1, _isPressed ? 1 : 2),
            ),
          ],
        ),
        child: Text(
          widget.trait,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SelectedChip extends StatefulWidget {
  final String trait;
  final Function(String) onDeselected;
  const SelectedChip(
      {super.key, required this.trait, required this.onDeselected});

  @override
  State<SelectedChip> createState() => _SelectedChipState();
}

class _SelectedChipState extends State<SelectedChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => widget.onDeselected(widget.trait),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.deepPurpleAccent.withOpacity(0.3)
                  : theme.primaryColor.withOpacity(_isPressed ? 0.1 : 0.2),
              blurRadius: _isPressed ? 4 : 8,
              offset: Offset(2, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.trait,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class RelatedChip extends StatefulWidget {
  final String trait;
  final Function(String) onSelected;
  const RelatedChip({super.key, required this.trait, required this.onSelected});

  @override
  State<RelatedChip> createState() => _RelatedChipState();
}

class _RelatedChipState extends State<RelatedChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => widget.onSelected(widget.trait),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor.withOpacity(0.65),
              theme.primaryColor.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark ? Colors.white70 : theme.primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : theme.shadowColor.withOpacity(_isPressed ? 0.05 : 0.1),
              blurRadius: _isPressed ? 2 : 4,
              offset: Offset(1, _isPressed ? 1 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.trait,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color:
                  isDark ? Colors.white70 : theme.primaryColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
