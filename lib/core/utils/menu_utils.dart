import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:read_leaf/features/reader/presentation/blocs/reader_bloc.dart';

/// Common menu utilities for both PDF and EPUB viewers
class MenuUtils {
  /// Toggle side navigation panel
  static void toggleSideNav(
    BuildContext context, {
    required bool showSearchPanel,
    required Function(bool) updateSearchPanel,
    Function? resetTextSearch,
  }) {
    final readerBloc = context.read<ReaderBloc>();
    final state = readerBloc.state;
    if (state is ReaderLoaded) {
      // If search panel is open, close it first
      if (showSearchPanel) {
        updateSearchPanel(false);
        resetTextSearch?.call();
      }
      readerBloc.add(ToggleSideNav());
    }
  }

  /// Close side navigation panel
  static void closeSideNav(
    BuildContext context, {
    required bool showSearchPanel,
    required Function(bool) updateSearchPanel,
    Function? resetTextSearch,
  }) {
    final readerBloc = context.read<ReaderBloc>();
    final state = readerBloc.state;
    if (state is ReaderLoaded && state.showSideNav) {
      // Close search panel if it's open
      if (showSearchPanel) {
        updateSearchPanel(false);
        resetTextSearch?.call();
      }
      readerBloc.add(ToggleSideNav());
    }
  }

  /// Toggle search panel
  static void toggleSearchPanel(
    BuildContext context, {
    required bool showSearchPanel,
    required Function(bool) updateSearchPanel,
    required Function(UniqueKey) updateSearchKey,
    Function? resetTextSearch,
  }) {
    // Close side nav if it's open
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      if (state.showSideNav) {
        context.read<ReaderBloc>().add(ToggleSideNav());
      }
    }

    final newState = !showSearchPanel;
    updateSearchPanel(newState);

    if (newState) {
      updateSearchKey(UniqueKey());
    } else {
      resetTextSearch?.call();
    }
  }

  /// Close search panel
  static void closeSearchPanel({
    required Function(bool) updateSearchPanel,
    Function? resetTextSearch,
  }) {
    updateSearchPanel(false);
    resetTextSearch?.call();
  }

  /// Handle tap on viewer
  static void handleTap(
    BuildContext context, {
    required bool showSearchPanel,
    required Function(bool) updateSearchPanel,
    Function? resetTextSearch,
  }) {
    // Close any open side widgets first
    if (showSearchPanel) {
      updateSearchPanel(false);
      resetTextSearch?.call();
    }

    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      if (state.showSideNav) {
        closeSideNav(
          context,
          showSearchPanel: showSearchPanel,
          updateSearchPanel: updateSearchPanel,
          resetTextSearch: resetTextSearch,
        );
      }
    }

    // Toggle UI visibility after handling side widgets
    context.read<ReaderBloc>().add(ToggleUIVisibility());
  }

  /// Show reader settings menu
  static void showSettingsMenu(
    BuildContext context, {
    required String filePath,
    required Function(dynamic) onLayoutModeChanged,
    required dynamic currentLayoutMode,
    required dynamic convertFunction,
    required Function showMenuFunction,
    bool showFacingOption = true,
  }) {
    showMenuFunction(
      context: context,
      filePath: filePath,
      currentLayoutMode: convertFunction(currentLayoutMode),
      onLayoutModeChanged: onLayoutModeChanged,
      showFacingOption: showFacingOption,
    );
  }

  /// Add highlight for PDF
  static void addHighlightPdf(
    BuildContext context, {
    required PdfViewerController controller,
    required List<PdfTextRanges>? textSelections,
    required Color color,
    required Map<int, List<dynamic>> markers,
    required Function setState,
  }) {
    if (controller.isReady && textSelections != null) {
      for (final selectedText in textSelections) {
        markers
            .putIfAbsent(selectedText.pageNumber, () => [])
            .add(Marker(color, selectedText));

        // Save highlight to BookMetadata
        context.read<ReaderBloc>().add(AddHighlight(
              text: selectedText.text,
              note: null,
              pageNumber: selectedText.pageNumber,
            ));
      }
      setState();
    }
  }

  /// Delete highlight for PDF
  static void deleteMarkerPdf(
    BuildContext context, {
    required dynamic marker,
    required Map<int, List<dynamic>> markers,
    required Function setState,
  }) {
    markers[marker.ranges.pageNumber]!.remove(marker);

    // Remove highlight from BookMetadata
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      final updatedHighlights = state.metadata.highlights
          .where((h) =>
              h.text != marker.ranges.text ||
              h.pageNumber != marker.ranges.pageNumber)
          .toList();

      final updatedMetadata =
          state.metadata.copyWith(highlights: updatedHighlights);
      context.read<ReaderBloc>().add(UpdateMetadata(updatedMetadata));
    }

    setState();
  }

  /// Add highlight for EPUB
  static void addHighlightEpub(
    BuildContext context, {
    required String selectedText,
    required int currentPage,
    required Color color,
    required Map<int, List<dynamic>> markers,
    required Function setState,
    dynamic cfiRange,
  }) {
    if (selectedText.isNotEmpty) {
      // Add to local markers collection
      markers.putIfAbsent(currentPage, () => []).add({
        'text': selectedText,
        'color': color,
        'pageNumber': currentPage,
        'cfiRange': cfiRange,
      });

      // Save highlight to BookMetadata
      context.read<ReaderBloc>().add(AddHighlight(
            text: selectedText,
            note: null,
            pageNumber: currentPage,
          ));

      setState();
    }
  }

  /// Delete highlight for EPUB
  static void deleteMarkerEpub(
    BuildContext context, {
    required dynamic marker,
    required Map<int, List<dynamic>> markers,
    required Function setState,
  }) {
    final pageNumber = marker['pageNumber'] as int;
    markers[pageNumber]!.remove(marker);

    // Remove highlight from BookMetadata
    if (context.read<ReaderBloc>().state is ReaderLoaded) {
      final state = context.read<ReaderBloc>().state as ReaderLoaded;
      final updatedHighlights = state.metadata.highlights
          .where((h) => h.text != marker['text'] || h.pageNumber != pageNumber)
          .toList();

      final updatedMetadata =
          state.metadata.copyWith(highlights: updatedHighlights);
      context.read<ReaderBloc>().add(UpdateMetadata(updatedMetadata));
    }

    setState();
  }
}

/// Marker class for PDF highlights
class Marker {
  final Color color;
  final PdfTextRanges ranges;

  Marker(this.color, this.ranges);
}
