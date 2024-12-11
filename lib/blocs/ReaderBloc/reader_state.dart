part of 'reader_bloc.dart';

abstract class ReaderState extends Equatable {
  const ReaderState();

  @override
  List<Object> get props => [];
}

class ReaderInitial extends ReaderState {}

class ReaderLoading extends ReaderState {}

class ReaderLoaded extends ReaderState {
  final File file;
  final dynamic contentParsed;

  const ReaderLoaded(this.contentParsed, {required this.file});

  @override
  List<Object> get props => [file];
}

class ReaderError extends ReaderState {
  final String message;

  const ReaderError(this.message);

  @override
  List<Object> get props => [message];
}
