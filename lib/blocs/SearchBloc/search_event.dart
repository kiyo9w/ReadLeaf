part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object> get props => [];
}

class SearchBooks extends SearchEvent {
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

class LoadBookInfo extends SearchEvent {
  final String url;

  const LoadBookInfo(this.url);

  @override
  List<Object> get props => [url];
}

class DownloadBook extends SearchEvent {
  final String url;
  final String fileName;

  const DownloadBook({required this.url, required this.fileName});

  @override
  List<Object> get props => [url, fileName];
}
