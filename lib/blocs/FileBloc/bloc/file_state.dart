part of 'file_bloc.dart';

abstract class FileState extends Equatable {
  const FileState();

  @override
  List<Object> get props => [];
}

class FileInitial extends FileState {}

class FileLoading extends FileState {}

class FileLoaded extends FileState {
  final String filePath;
  final int fileSize;

  const FileLoaded(
    this.filePath,
    this.fileSize,
  );

  @override
  List<Object> get props => [filePath, fileSize];
}

class FileError extends FileState {
  final String message;

  const FileError({required this.message});

  @override
  List<Object> get props => [message];
}

class FileName extends FileState {
  final String name;

  const FileName({required this.name});

  @override
  List<Object> get props => [name];
}
