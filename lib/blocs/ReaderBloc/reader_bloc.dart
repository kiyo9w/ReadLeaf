import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';

part 'reader_event.dart';
part 'reader_state.dart';

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc() : super(ReaderInitial());

  @override
  Stream<ReaderState> mapEventToState(ReaderEvent event) async* {
    if (event is OpenReader) {
      yield* _mapOpenReaderToState(event);
    } else if (event is NextPage) {
      yield* _mapNextPageToState();
    } else if (event is PreviousPage) {
      yield* _mapPreviousPageToState();
    } else if (event is JumpToPage) {
      yield* _mapJumpToPageToState(event);
    } else if (event is SetZoomLevel) {
      yield* _mapSetZoomLevelToState(event);
    } else if (event is ToggleReadingMode) {
      yield* _mapToggleReadingModeToState();
    } else if (event is CloseReader) {
      yield* _mapCloseReaderToState();
    }
  }

  Stream<ReaderState> _mapOpenReaderToState(OpenReader event) async* {
    yield ReaderLoading();
    try {
      final fileType = FileParser.determineFileType(event.filePath);
      if (fileType == "unknown") {
        yield ReaderError("Unsupported file format");
        return;
      }
      final totalPages = 100; // Replace with logic later
      yield ReaderLoaded(
        totalPages: totalPages,
        currentPage: 1, // Replace with logic to get saved page
        zoomLevel: 1.0,
        isNightMode: false,
        file: event.file,
      );
    } catch (e) {
      yield ReaderError(e.toString());
    }
  }

  Stream<ReaderState> _mapNextPageToState() async* {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      if (currentState.currentPage < currentState.totalPages) {
        yield currentState.copyWith(currentPage: currentState.currentPage + 1);
      }
    }
  }

  Stream<ReaderState> _mapPreviousPageToState() async* {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      if (currentState.currentPage > 1) {
        yield currentState.copyWith(currentPage: currentState.currentPage - 1);
      }
    }
  }

  Stream<ReaderState> _mapJumpToPageToState(JumpToPage event) async* {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      if (event.pageIndex > 0 && event.pageIndex <= currentState.totalPages) {
        yield currentState.copyWith(currentPage: event.pageIndex);
      }
    }
  }

  Stream<ReaderState> _mapSetZoomLevelToState(SetZoomLevel event) async* {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      yield currentState.copyWith(zoomLevel: event.zoomLevel);
    }
  }

  Stream<ReaderState> _mapToggleReadingModeToState() async* {
    if (state is ReaderLoaded) {
      final currentState = state as ReaderLoaded;
      yield currentState.copyWith(isNightMode: !currentState.isNightMode);
    }
  }

  Stream<ReaderState> _mapCloseReaderToState() async* {
    yield ReaderInitial();
  }
}

class FileParser {
  static String determineFileType(String filePath) {
    if (filePath.endsWith(".pdf")) return "pdf";
    if (filePath.endsWith(".mobi")) return "mobi";
    if (filePath.endsWith(".md")) return "markdown";
    return "unknown";
  }

  Future<dynamic> parseFile(File file, String fileType) async {
    dynamic content;
    if (fileType == "pdf") {
      // logic
    } else if (fileType == "mobi") {
      // logic
    } else if (fileType == "markdown") {
      // logic
    } else {
      content = "Can't read unsupported format file";
    }
    return content;
  }
}