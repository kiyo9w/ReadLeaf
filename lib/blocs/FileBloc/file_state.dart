part of 'file_bloc.dart';

abstract class FileState extends Equatable {
  const FileState();

  @override
  List<Object> get props => [];
}

class FileInitial extends FileState {}

class FileLoaded extends FileState {
  final List<FileInfo> files;
  final FileInfo? lastRemovedFile;

  const FileLoaded(this.files, {this.lastRemovedFile});

  @override
  List<Object> get props =>
      [files, if (lastRemovedFile != null) lastRemovedFile!];
}

class FileViewing extends FileLoaded {
  final String filePath;

  const FileViewing(List<FileInfo> files, this.filePath) : super(files);

  @override
  List<Object> get props => [...super.props, filePath];
}

class FileScanning extends FileState {}

class FileError extends FileState {
  final String message;

  const FileError({required this.message});

  @override
  List<Object> get props => [message];
}
