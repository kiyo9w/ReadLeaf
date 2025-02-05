import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:read_leaf/services/annas_archieve.dart';
import 'package:read_leaf/utils/file_utils.dart';
import 'package:path/path.dart' as path;
import 'package:read_leaf/models/file_info.dart';
import 'dart:io';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final AnnasArchieve annasArchieve;
  final FileRepository fileRepository;

  SearchBloc({
    required this.annasArchieve,
    required this.fileRepository,
  }) : super(SearchInitial()) {
    on<SearchBooks>(_onSearchBooks);
    on<LoadBookInfo>(_onLoadBookInfo);
    on<DownloadBook>(_onDownloadBook);
  }

  Future<void> _onSearchBooks(
      SearchBooks event, Emitter<SearchState> emit) async {
    try {
      emit(SearchLoading());
      final books = await annasArchieve.searchBooks(
        searchQuery: event.query,
        content: event.content,
        sort: event.sort,
        fileType: event.fileType,
        enableFilters: event.enableFilters,
      );
      emit(SearchResults(books));
    } catch (e) {
      emit(SearchError(message: e.toString()));
    }
  }

  Future<void> _onLoadBookInfo(
      LoadBookInfo event, Emitter<SearchState> emit) async {
    try {
      emit(BookInfoLoading());
      final bookInfo = await annasArchieve.bookInfo(url: event.url);
      emit(BookInfoLoaded(bookInfo));
    } catch (e) {
      emit(SearchError(message: e.toString()));
    }
  }

  Future<void> _onDownloadBook(
      DownloadBook event, Emitter<SearchState> emit) async {
    try {
      emit(DownloadProgress(0.0));

      final downloadsPath = await FileUtils.getDownloadsDirectory();
      final localFilePath = path.join(downloadsPath, event.fileName);

      Dio dio = Dio();
      await dio.download(
        event.url,
        localFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            emit(DownloadProgress(progress));
          }
        },
      );

      final file = File(localFilePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          // Add the downloaded file to FileRepository
          final currentFiles = await fileRepository.loadFiles();
          final newFiles = [...currentFiles, FileInfo(localFilePath, fileSize)];
          await fileRepository.saveFiles(newFiles);
          emit(DownloadComplete(localFilePath));
        } else {
          throw Exception('Downloaded file is empty');
        }
      } else {
        throw Exception('File was not created after download');
      }
    } catch (e) {
      emit(SearchError(message: 'Download failed: ${e.toString()}'));
    }
  }
}
