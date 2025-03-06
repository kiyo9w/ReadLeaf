import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:read_leaf/injection/injection.dart';
import 'package:read_leaf/features/library/domain/models/book_metadata.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';

part 'reader_event.dart';
part 'reader_state.dart';

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  final BookMetadataRepository _metadataRepository =
      getIt<BookMetadataRepository>();

  ReaderBloc() : super(ReaderInitial()) {
    on<OpenReader>(_onOpenReader);
    on<NextPage>(_onNextPage);
    on<PreviousPage>(_onPreviousPage);
    on<JumpToPage>(_onJumpToPage);
    on<SetZoomLevel>(_onSetZoomLevel);
    on<SetFontSize>(_onSetFontSize);
    on<ToggleReadingMode>(_onToggleReadingMode);
    on<setReadingMode>(_onSetReadingMode);
    on<CloseReader>(_onCloseReader);
    on<ToggleUIVisibility>(_onToggleUIVisibility);
    on<ToggleSideNav>(_onToggleSideNav);
    on<AddHighlight>(_onAddHighlight);
    on<AddAiConversation>(_onAddAiConversation);
    on<UpdateMetadata>(_onUpdateMetadata);
  }

  void _onOpenReader(OpenReader event, Emitter<ReaderState> emit) async {
    emit(ReaderLoading());
    try {
      final fileType = FileParser.determineFileType(event.filePath);
      if (fileType == "unknown") {
        emit(ReaderError("Unsupported file format"));
        return;
      }

      // Get the total pages from the document
      int totalPages = 100; // Default value
      if (fileType == "pdf") {
        final document = await PdfDocument.openFile(event.filePath);
        totalPages = document.pages.length;
        await document.dispose();
      } else if (fileType == "epub") {
        // For EPUB, we'll use a default value since page count isn't readily available
        totalPages = 1000; // Default value for EPUB
      }

      // Get or create metadata
      BookMetadata? metadata = _metadataRepository.getMetadata(event.filePath);
      if (metadata == null) {
        metadata = BookMetadata(
          filePath: event.filePath,
          title: path.basename(event.filePath),
          totalPages: totalPages,
          lastReadTime: DateTime.now(),
          fileType: fileType,
        );
        await _metadataRepository.saveMetadata(metadata);
      } else {
        // Update the total pages in case it was incorrect before
        if (metadata.totalPages != totalPages) {
          metadata = metadata.copyWith(totalPages: totalPages);
          await _metadataRepository.saveMetadata(metadata);
        }
      }

      emit(ReaderLoaded(
        totalPages: metadata.totalPages,
        currentPage: metadata.lastOpenedPage,
        zoomLevel: 1.0,
        readingMode: ReadingMode.light,
        file: event.file,
        contentParsed: event.contentParsed,
        showUI: true,
        showSideNav: false,
        metadata: metadata,
      ));
    } catch (e) {
      emit(ReaderError(e.toString()));
    }
  }

  void _onNextPage(NextPage event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (s.currentPage < s.totalPages) {
        final newPage = s.currentPage + 1;
        await _metadataRepository.updateLastOpenedPage(s.file.path, newPage);
        emit(s.copyWith(currentPage: newPage));
      }
    }
  }

  void _onPreviousPage(PreviousPage event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (s.currentPage > 1) {
        final newPage = s.currentPage - 1;
        await _metadataRepository.updateLastOpenedPage(s.file.path, newPage);
        emit(s.copyWith(currentPage: newPage));
      }
    }
  }

  void _onJumpToPage(JumpToPage event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      if (event.pageIndex > 0 && event.pageIndex <= s.totalPages) {
        // Only update if the page actually changed
        if (event.pageIndex != s.currentPage) {
          await _metadataRepository.updateLastOpenedPage(
              s.file.path, event.pageIndex);
          emit(s.copyWith(currentPage: event.pageIndex));
        }
      }
    }
  }

  void _onSetZoomLevel(SetZoomLevel event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      // Only update if the zoom level actually changed
      if (event.zoomLevel != s.zoomLevel) {
        emit(s.copyWith(zoomLevel: event.zoomLevel));
      }
    }
  }

  void _onSetFontSize(SetFontSize event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      // Only update if the font size actually changed
      if (event.fontSize != s.fontSize) {
        emit(s.copyWith(fontSize: event.fontSize));
      }
    }
  }

  void _onToggleReadingMode(
      ToggleReadingMode event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      final newMode = s.readingMode == ReadingMode.light
          ? ReadingMode.dark
          : ReadingMode.light;
      emit(s.copyWith(readingMode: newMode));
    }
  }

  void _onSetReadingMode(setReadingMode event, Emitter<ReaderState> emit) {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      emit(s.copyWith(readingMode: event.mode));
    }
  }

  void _onCloseReader(CloseReader event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      // Save any final state if needed
      await _metadataRepository.updateLastOpenedPage(
          s.file.path, s.currentPage);
    }
    emit(ReaderInitial());
  }

  void _onToggleUIVisibility(
      ToggleUIVisibility event, Emitter<ReaderState> emit) {
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

  void _onAddHighlight(AddHighlight event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      final highlight = TextHighlight(
        text: event.text,
        pageNumber: event.pageNumber,
        createdAt: DateTime.now(),
        note: event.note,
      );

      // Batch metadata updates
      await Future.wait([
        _metadataRepository.addHighlight(s.file.path, highlight),
        _updateMetadataState(s, emit),
      ]);
    }
  }

  void _onAddAiConversation(
      AddAiConversation event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      final conversation = AiConversation(
        selectedText: event.selectedText,
        aiResponse: event.aiResponse,
        timestamp: DateTime.now(),
        pageNumber: s.currentPage,
      );

      // Batch metadata updates
      await Future.wait([
        _metadataRepository.addAiConversation(s.file.path, conversation),
        _updateMetadataState(s, emit),
      ]);
    }
  }

  Future<void> _updateMetadataState(
      ReaderLoaded state, Emitter<ReaderState> emit) async {
    final updatedMetadata = _metadataRepository.getMetadata(state.file.path);
    if (updatedMetadata != null) {
      emit(state.copyWith(metadata: updatedMetadata));
    }
  }

  void _onUpdateMetadata(
      UpdateMetadata event, Emitter<ReaderState> emit) async {
    if (state is ReaderLoaded) {
      final s = state as ReaderLoaded;
      await _metadataRepository.saveMetadata(event.metadata);
      emit(s.copyWith(metadata: event.metadata));
    }
  }
}

class FileParser {
  static String determineFileType(String filePath) {
    if (filePath.endsWith(".pdf")) return "pdf";
    if (filePath.endsWith(".mobi")) return "mobi";
    if (filePath.endsWith(".md")) return "markdown";
    if (filePath.endsWith(".epub")) return "epub";
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
