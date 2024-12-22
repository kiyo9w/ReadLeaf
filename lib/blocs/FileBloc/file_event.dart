part of 'file_bloc.dart';

abstract class FileEvent extends Equatable {
  const FileEvent();

  @override
  List<Object> get props => [];
}

class InitFiles extends FileEvent {}

class LoadFile extends FileEvent {
  final String filePath;

  const LoadFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class CloseViewer extends FileEvent {}

class SelectFile extends FileEvent {
  final String filePath;

  const SelectFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class ViewFile extends FileEvent {
  final String filePath;

  const ViewFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class RemoveFile extends FileEvent {
  final String filePath;

  const RemoveFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class SearchBooks extends FileEvent {
  final String query;
  final String content;
  final String sort;
  final String fileType;
  final bool enableFilters;

  const SearchBooks({
    required this.query,
    this.content = "",
    this.sort = "",
    this.fileType = "",
    this.enableFilters = true,
  });

  @override
  List<Object> get props => [query, content, sort, fileType, enableFilters];
}

class LoadBookInfo extends FileEvent {
  final String url;

  const LoadBookInfo(this.url);

  @override
  List<Object> get props => [url];
}

class DownloadFile extends FileEvent {
  final String url;
  final String fileName;

  const DownloadFile({required this.url, required this.fileName});

  @override
  List<Object> get props => [url, fileName];
}

class ToggleStarred extends FileEvent {
  final String filePath;

  const ToggleStarred(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class MarkAsRead extends FileEvent {
  final String filePath;

  const MarkAsRead(this.filePath);

  @override
  List<Object> get props => [filePath];
}
