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

class FileScanning extends FileState {}

class FileError extends FileState {
  final String message;

  const FileError({required this.message});

  @override
  List<Object> get props => [message];
}
