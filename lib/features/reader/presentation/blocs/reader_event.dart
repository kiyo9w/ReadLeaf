part of 'reader_bloc.dart';

abstract class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object?> get props => [];
}

class ParseFile extends ReaderEvent {
  final File file;
  final String fileType;
  const ParseFile({required this.file, required this.fileType});
}

class OpenReader extends ReaderEvent {
  final File file;
  final String contentParsed;
  final String filePath;

  const OpenReader(this.contentParsed, {required this.file, required this.filePath});

  @override
  List<Object> get props => [file, filePath, contentParsed];
}

class CloseReader extends ReaderEvent {}

class NextPage extends ReaderEvent {}

class PreviousPage extends ReaderEvent {}

class JumpToPage extends ReaderEvent {
  final int pageIndex;

  const JumpToPage(this.pageIndex);

  @override
  List<Object> get props => [pageIndex];
}

class SetZoomLevel extends ReaderEvent {
  final double zoomLevel;

  const SetZoomLevel(this.zoomLevel);

  @override
  List<Object> get props => [zoomLevel];
}

class setReadingMode extends ReaderEvent {
  final ReadingMode mode;

  const setReadingMode(this.mode);

  @override
  List<Object> get props => [mode];
}

class ToggleReadingMode extends ReaderEvent {}

class ToggleUIVisibility extends ReaderEvent {}

class ToggleSideNav extends ReaderEvent {}

class AddHighlight extends ReaderEvent {
  final String text;
  final String? note;
  final int pageNumber;

  const AddHighlight({
    required this.text,
    this.note,
    required this.pageNumber,
  });

  @override
  List<Object?> get props => [text, note, pageNumber];
}

class AddAiConversation extends ReaderEvent {
  final String selectedText;
  final String aiResponse;

  const AddAiConversation({
    required this.selectedText,
    required this.aiResponse,
  });

  @override
  List<Object> get props => [selectedText, aiResponse];
}

class UpdateMetadata extends ReaderEvent {
  final BookMetadata metadata;

  const UpdateMetadata(this.metadata);

  @override
  List<Object> get props => [metadata];
}
