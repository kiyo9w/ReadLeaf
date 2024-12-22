part of 'file_bloc.dart';

abstract class FileState extends Equatable {
  const FileState();

  @override
  List<Object> get props => [];
}

class FileInitial extends FileState {}

class FileLoaded extends FileState {
  final List<FileInfo> files;

  const FileLoaded(this.files);

  @override
  List<Object> get props => [files];
}

class FileViewing extends FileState {
  final String filePath;

  const FileViewing(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class FileError extends FileState {
  final String message;

  const FileError({required this.message});

  @override
  List<Object> get props => [message];
}

class FileSearchLoading extends FileState {}

class FileSearchResults extends FileState {
  final List<BookData> books;

  const FileSearchResults(this.books);

  @override
  List<Object> get props => [books];
}

class FileBookInfoLoading extends FileState {}

class FileBookInfoLoaded extends FileState {
  final BookInfoData bookInfo;

  const FileBookInfoLoaded(this.bookInfo);

  @override
  List<Object> get props => [bookInfo];
}

class FileLoading extends FileState {}

class FileDownloading extends FileState {
  final double progress;
  const FileDownloading(this.progress);

  @override
  List<Object> get props => [progress];
}
