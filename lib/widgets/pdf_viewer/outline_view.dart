import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:read_leaf/blocs/ReaderBloc/reader_bloc.dart';

class OutlineNode {
  final PdfOutlineNode node;
  final int level;
  final List<OutlineNode> children;
  bool isExpanded;

  OutlineNode({
    required this.node,
    required this.level,
    this.children = const [],
    this.isExpanded = false,
  });
}

class OutlineView extends StatefulWidget {
  const OutlineView({
    super.key,
    required this.outline,
    required this.controller,
  });

  final List<PdfOutlineNode>? outline;
  final PdfViewerController controller;

  @override
  State<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends State<OutlineView> {
  late List<OutlineNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes(widget.outline, 0);
  }

  @override
  void didUpdateWidget(OutlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outline != widget.outline) {
      _nodes = _buildNodes(widget.outline, 0);
    }
  }

  List<OutlineNode> _buildNodes(List<PdfOutlineNode>? outline, int level) {
    if (outline == null) return [];

    return outline.map((node) {
      return OutlineNode(
        node: node,
        level: level,
        children: _buildNodes(node.children, level + 1),
      );
    }).toList();
  }

  Widget _buildNode(OutlineNode node, bool isLastChild) {
    final hasChildren = node.children.isNotEmpty;
    final isTopLevel = node.level == 0;

    return BlocBuilder<ReaderBloc, ReaderState>(
      builder: (context, state) {
        final currentPage = state is ReaderLoaded ? state.currentPage : 1;

        // Find the closest node to current page for highlighting
        bool shouldHighlight = false;
        if (node.node.dest?.pageNumber != null) {
          final pageNumber = node.node.dest!.pageNumber;
          final List<int> samePageNodes = _nodes
              .expand((n) => _flattenNodes(n))
              .where((n) => n.node.dest?.pageNumber == pageNumber)
              .map((n) => n.node.dest!.pageNumber)
              .toList();

          if (samePageNodes.contains(pageNumber)) {
            final pagesBeforeCurrent = _nodes
                .expand((n) => _flattenNodes(n))
                .where((n) =>
                    n.node.dest?.pageNumber != null &&
                    n.node.dest!.pageNumber <= currentPage)
                .map((n) => n.node.dest!.pageNumber)
                .toList();

            shouldHighlight = pageNumber <= currentPage &&
                (pagesBeforeCurrent.isEmpty
                    ? false
                    : pagesBeforeCurrent.reduce((a, b) => a > b ? a : b) ==
                        pageNumber);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: shouldHighlight
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF8F1F1))
                  : Colors.transparent,
              child: Row(
                children: [
                  if (hasChildren)
                    InkWell(
                      onTap: () {
                        setState(() {
                          node.isExpanded = !node.isExpanded;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: Icon(
                          node.isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF6E6E73),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 32),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        widget.controller.goToDest(node.node.dest);
                        if (node.node.dest?.pageNumber != null) {
                          context
                              .read<ReaderBloc>()
                              .add(JumpToPage(node.node.dest!.pageNumber));
                          context.read<ReaderBloc>().add(ToggleSideNav());
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.only(
                          right: 16,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                node.node.title,
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF2F2F7)
                                      : const Color(0xFF1C1C1E),
                                  fontSize: isTopLevel ? 14 : 13,
                                  fontWeight: isTopLevel
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (node.node.dest?.pageNumber != null)
                              Text(
                                '${node.node.dest!.pageNumber}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF6E6E73),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (node.isExpanded && hasChildren)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < node.children.length; i++)
                      _buildNode(
                          node.children[i], i == node.children.length - 1),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<OutlineNode> _flattenNodes(OutlineNode node) {
    List<OutlineNode> result = [node];
    for (var child in node.children) {
      result.addAll(_flattenNodes(child));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
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
              'This document has no table of contents',
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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var i = 0; i < _nodes.length; i++)
          _buildNode(_nodes[i], i == _nodes.length - 1),
      ],
    );
  }
}
