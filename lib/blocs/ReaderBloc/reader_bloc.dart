import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'reader_event.dart';
part 'reader_state.dart';

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc() : super(ReaderInitial()) {
    on<OpenReader>(_onOpenReader);
    on<NextPage>(_onNextPage);
    on<PreviousPage>(_onPreviousPage);
    on<JumpToPage>(_onJumpToPage);
    on<SetZoomLevel>(_onSetZoomLevel);
    on<ToggleReadingMode>(_onToggleReadingMode);
    on<CloseReader>(_onCloseReader);
    on<ToggleUIVisibility>(_onToggleUIVisibility);
    on<ToggleSideNav>(_onToggleSideNav);
  }

  void _onOpenReader(OpenReader event, Emitter<ReaderState> emit) async {
    emit(ReaderLoading());
    try {
      final fileType = FileParser.determineFileType(event.filePath);
      if (fileType == "unknown") {
        emit(ReaderError("Unsupported file format"));
        return;
      }
      // Logic for total page and current page (last read) later
      final totalPages = 100;
      emit(ReaderLoaded(
        totalPages: totalPages,
        currentPage: 1, //
        zoomLevel: 1.0,
        isNightMode: false,
        file: event.file,
        contentParsed: event.contentParsed,
        showUI: true,
        showSideNav: false,
      ));
    } catch (e) {
      emit(ReaderError(e.toString()));
    }
  }

  void _onNextPage(NextPage event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (s.currentPage < s.totalPages) {
        emit(s.copyWith(currentPage: s.currentPage + 1));
      }
    }
  }

  void _onPreviousPage(PreviousPage event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (s.currentPage > 1) {
        emit(s.copyWith(currentPage: s.currentPage - 1));
      }
    }
  }

  void _onJumpToPage(JumpToPage event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (event.pageIndex > 0 && event.pageIndex <= s.totalPages) {
        emit(s.copyWith(currentPage: event.pageIndex));
      }
    }
  }

  void _onSetZoomLevel(SetZoomLevel event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      emit(s.copyWith(zoomLevel: event.zoomLevel));
    }
  }

  void _onToggleReadingMode(ToggleReadingMode event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      emit(s.copyWith(isNightMode: !s.isNightMode));
    }
  }

  void _onCloseReader(CloseReader event, Emitter<ReaderState> emit) {
    emit(ReaderInitial());
  }

  void _onToggleUIVisibility(ToggleUIVisibility event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      emit(s.copyWith(showUI: !s.showUI));
    }
  }

  void _onToggleSideNav(ToggleSideNav event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      emit(s.copyWith(showSideNav: !s.showSideNav));
    }
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
      // logic to parse PDF if needed
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