part of 'reader_bloc.dart';

abstract class ReaderState extends Equatable {
  const ReaderState();

  @override
  List<Object?> get props => [];
}

class ReaderInitial extends ReaderState {}

class ReaderLoading extends ReaderState {}

class ReaderLoaded extends ReaderState {
  final int totalPages;
  final int currentPage;
  final double zoomLevel;
  final bool isNightMode;
  final File file;
  final dynamic contentParsed;
  final bool showUI;
  final bool showSideNav;
  final BookMetadata metadata;

  const ReaderLoaded({
    required this.totalPages,
    required this.currentPage,
    required this.zoomLevel,
    required this.isNightMode,
    required this.file,
    this.contentParsed,
    required this.showUI,
    required this.showSideNav,
    required this.metadata,
  });

  @override
  List<Object?> get props => [
        totalPages,
        currentPage,
        zoomLevel,
        isNightMode,
        file,
        contentParsed,
        showUI,
        showSideNav,
        metadata,
      ];

  ReaderLoaded copyWith({
    int? totalPages,
    int? currentPage,
    double? zoomLevel,
    bool? isNightMode,
    File? file,
    dynamic contentParsed,
    bool? showUI,
    bool? showSideNav,
    BookMetadata? metadata,
  }) {
    return ReaderLoaded(
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      isNightMode: isNightMode ?? this.isNightMode,
      file: file ?? this.file,
      contentParsed: contentParsed ?? this.contentParsed,
      showUI: showUI ?? this.showUI,
      showSideNav: showSideNav ?? this.showSideNav,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ReaderError extends ReaderState {
  final String message;

  const ReaderError(this.message);

  @override
  List<Object> get props => [message];
}
