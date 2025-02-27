part of 'search_bloc.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchResults extends SearchState {
  final List<BookData> books;

  const SearchResults(this.books);

  @override
  List<Object> get props => [books];
}

class BookInfoLoading extends SearchState {}

class BookInfoLoaded extends SearchState {
  final BookInfoData bookInfo;

  const BookInfoLoaded(this.bookInfo);

  @override
  List<Object> get props => [bookInfo];
}

class DownloadProgress extends SearchState {
  final double progress;

  const DownloadProgress(this.progress);

  @override
  List<Object> get props => [progress];
}

class DownloadComplete extends SearchState {
  final String filePath;

  const DownloadComplete(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class SearchError extends SearchState {
  final String message;

  const SearchError({required this.message});

  @override
  List<Object> get props => [message];
}
