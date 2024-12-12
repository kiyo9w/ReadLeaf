part of 'reader_bloc.dart';

abstract class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object> get props => [];
}

class ParseFile extends ReaderEvent {
  final File file;
  final String fileType;
  ParseFile({required this.file, required this.fileType});
}

class OpenReader extends ReaderEvent {
  final File file;
  final String contentParsed;
  final String filePath;

  OpenReader(this.contentParsed, {required this.file, required this.filePath});

  @override
  List<Object> get props => [];
}

class CloseReader extends ReaderEvent {
  final File file;

  CloseReader(this.file);

  @override
  List<Object> get props => [];
}

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

class ToggleReadingMode extends ReaderEvent {}