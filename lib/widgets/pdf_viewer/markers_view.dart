import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/ReaderBloc/reader_bloc.dart';

class Marker {
  final Color color;
  final PdfTextRanges ranges;

  Marker(this.color, this.ranges);
}

class MarkersView extends StatefulWidget {
  const MarkersView({
    super.key,
    required this.markers,
    this.onTap,
    this.onDeleteTap,
  });

  final List<Marker> markers;
  final void Function(Marker ranges)? onTap;
  final void Function(Marker ranges)? onDeleteTap;

  @override
  State<MarkersView> createState() => _MarkersViewState();
}

class _MarkersViewState extends State<MarkersView> {
  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty) {
      return const Center(
        child: Text(
          'No bookmarks yet\nHighlight text to add bookmarks',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemBuilder: (context, index) {
        final marker = widget.markers[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Stack(
            children: [
              Material(
                color: marker.color.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    widget.onTap?.call(marker);
                    // Update bloc state with the page number
                    context
                        .read<ReaderBloc>()
                        .add(JumpToPage(marker.ranges.pageNumber));
                    // Close the side nav after jumping to the bookmark
                    context.read<ReaderBloc>().add(ToggleSideNav());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Page ${marker.ranges.pageNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          marker.ranges.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white70),
                  onPressed: () => widget.onDeleteTap?.call(marker),
                ),
              ),
            ],
          ),
        );
      },
      itemCount: widget.markers.length,
    );
  }
}
