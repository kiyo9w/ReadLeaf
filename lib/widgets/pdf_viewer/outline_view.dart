import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';

class OutlineView extends StatelessWidget {
  const OutlineView({
    super.key,
    required this.outline,
    required this.controller,
  });

  final List<PdfOutlineNode>? outline;
  final PdfViewerController controller;

  @override
  Widget build(BuildContext context) {
    final list = _getOutlineList(outline, 0).toList();
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No chapters found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return InkWell(
          onTap: () {
            // Update both controller and bloc
            controller.goToDest(item.node.dest);
            if (item.node.dest?.pageNumber != null) {
              context
                  .read<ReaderBloc>()
                  .add(JumpToPage(item.node.dest!.pageNumber));
            }
            // Close the side nav after jumping to the chapter
            context.read<ReaderBloc>().add(ToggleSideNav());
          },
          child: Container(
            margin: EdgeInsets.only(
              left: item.level * 16.0 + 8,
              top: 8,
              bottom: 8,
              right: 8,
            ),
            child: Text(
              item.node.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: item.level == 0 ? 16 : 14,
                fontWeight:
                    item.level == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Recursively create outline indent structure
  Iterable<({PdfOutlineNode node, int level})> _getOutlineList(
      List<PdfOutlineNode>? outline, int level) sync* {
    if (outline == null) return;
    for (var node in outline) {
      yield (node: node, level: level);
      yield* _getOutlineList(node.children, level + 1);
    }
  }
}
