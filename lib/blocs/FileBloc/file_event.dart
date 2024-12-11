part of 'file_bloc.dart';

abstract class FileEvent extends Equatable {
  const FileEvent();

  @override
  List<Object> get props => [];
}

class LoadFile extends FileEvent {
  final String filePath;

  const LoadFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class SelectFile extends FileEvent{
  final bool selected;

  const SelectFile(this.selected);

  @override
  List<Object> get props => [selected];
}