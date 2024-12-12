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

// New states for searching and book info
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