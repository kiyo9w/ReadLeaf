import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:path_provider/path_provider.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

part 'file_event.dart';

part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  final FileRepository fileRepository;
  final AnnasArchieve annasArchieve;
  FileLoaded? _lastLoadedState;

  FileBloc({required this.fileRepository, required this.annasArchieve})
      : super(FileInitial()) {
    on<InitFiles>(_onInitFiles);
    on<LoadFile>(_onLoadFile);
    on<SelectFile>(_onSelectFile);
    on<ViewFile>(_onViewFile);
    on<RemoveFile>(_onRemoveFile);
    on<CloseViewer>(_onCloseViewer);
    on<SearchBooks>(_onSearchBooks);
    on<LoadBookInfo>(_onLoadBookInfo);
    on<DownloadFile>(_onDownloadFile);
    on<ToggleStarred>(_onToggleStarred);
  }

  Future<void> _onInitFiles(InitFiles event, Emitter<FileState> emit) async {
    final savedFiles = await fileRepository.loadFiles();
    if (savedFiles.isNotEmpty) {
      final loadedState = FileLoaded(savedFiles);
      _lastLoadedState = loadedState;
      emit(loadedState);
    } else {
      emit(FileInitial());
    }
  }

  Future<void> _onLoadFile(LoadFile event, Emitter<FileState> emit) async {
    try {
      final filePath = event.filePath;
      final extension = filePath.split('.').last.toLowerCase();

      // if (!['pdf'].contains(extension)) {
      //   throw Exception('Unsupported file format');
      // }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File doesn\'t exist');
      }
      final fileSize = await file.length();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      } else if (state is FileDownloading) {
        currentFiles = (_lastLoadedState!.files);
      }

      final isFileAlreadyLoaded =
          currentFiles.any((existingFile) => existingFile.filePath == filePath);
      if (isFileAlreadyLoaded) {
        emit(FileLoaded(currentFiles));
      } else {
        final newFiles = [...currentFiles, FileInfo(filePath, fileSize)];
        final newState = FileLoaded(newFiles);
        _lastLoadedState = newState;
        emit(newState);
        await fileRepository.saveFiles(newFiles);
      }
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onSelectFile(SelectFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(isSelected: !file.isSelected);
        }
        return file;
      }).toList();

      final newState = FileLoaded(updatedFiles);
      _lastLoadedState = newState;
      emit(newState);

      await fileRepository.saveFiles(updatedFiles);
    }
  }

  void _onViewFile(ViewFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      _lastLoadedState = state as FileLoaded;
      final fileToView = _lastLoadedState!.files.firstWhere(
          (file) => file.filePath == event.filePath,
          orElse: () => _lastLoadedState!.files.first);
      emit(FileViewing(fileToView.filePath));
    }
    // } else if (state is FileSearchResults) {
    // emit(FileBookInfoLoading());
    // try {
    // final bookInfo = await annasArchieve.bookInfo(url: event.filePath);
    // _lastViewedInternetBookInfo = bookInfo;
    // emit(FileViewing(bookInfo.link));
    // } catch (e) {
    // emit(FileError(message: e.toString()));
    // }
    else if (state is FileSearchResults) {
      emit(FileViewing(event.filePath));
    }
  }

  Future<void> _onRemoveFile(RemoveFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentFiles = (state as FileLoaded).files;
      final updatedFiles = currentFiles
          .where((file) => file.filePath != event.filePath)
          .toList();

      if (updatedFiles.isEmpty) {
        _lastLoadedState = null;
        emit(FileInitial());
        await fileRepository.saveFiles([]);
      } else {
        final newState = FileLoaded(updatedFiles);
        _lastLoadedState = newState;
        emit(newState);
        await fileRepository.saveFiles(updatedFiles);
      }
    }
  }

  void _onCloseViewer(CloseViewer event, Emitter<FileState> emit) {
    if (state is FileViewing) {
      if (_lastLoadedState != null) {
        emit(_lastLoadedState!);
      } else {
        emit(FileInitial());
      }
    } else if (state is FileSearchResults ||
        state is FileBookInfoLoaded ||
        state is FileBookInfoLoading) {
      if (_lastLoadedState != null) {
        emit(_lastLoadedState!);
      } else {
        emit(FileInitial());
      }
    }
  }

  Future<void> _onSearchBooks(
      SearchBooks event, Emitter<FileState> emit) async {
    try {
      if (state is FileLoaded) {
        _lastLoadedState = state as FileLoaded;
      }
      emit(FileSearchLoading());
      final books = await annasArchieve.searchBooks(
        searchQuery: event.query,
        content: event.content,
        sort: event.sort,
        fileType: event.fileType,
        enableFilters: event.enableFilters,
      );
      emit(FileSearchResults(books));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onLoadBookInfo(
      LoadBookInfo event, Emitter<FileState> emit) async {
    try {
      emit(FileBookInfoLoading());
      final bookInfo = await annasArchieve.bookInfo(url: event.url);
      emit(FileBookInfoLoaded(bookInfo));
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onDownloadFile(
      DownloadFile event, Emitter<FileState> emit) async {
    try {
      emit(FileDownloading(0.0));

      // Check and request permissions
      if (!await _checkAndRequestPermissions()) {
        throw Exception('Storage permission denied');
      }

      // Get download directory based on platform
      final directory = await _getDownloadDirectory();
      if (directory == null) {
        throw Exception('Could not access download directory');
      }

      final localFilePath = '${directory.path}/${event.fileName}';
      final file = File(localFilePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      Dio dio = Dio();
      await dio.download(
        event.url,
        localFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            emit(FileDownloading(progress));
          }
        },
      );
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 0) {
          add(LoadFile(localFilePath));
        } else {
          throw Exception('Downloaded file is empty');
        }
      } else {
        throw Exception('File was not created after download');
      }
    } catch (e) {
      emit(FileError(message: 'Download failed: ${e.toString()}'));
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt <= 32) {
        // For Android 12 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        // For Android 13 and above
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS doesn't need explicit permission for downloads folder
      return true;
    }
    return false;
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Get the Downloads directory on Android
      final downloadsPath =
          await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS,
      );
      return Directory(downloadsPath);
    } else if (Platform.isIOS) {
      // On iOS, we'll use the Documents directory which is accessible to users
      return await getApplicationDocumentsDirectory();
    }
    return null;
  }

  Future<void> _onToggleStarred(
      ToggleStarred event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(isStarred: !file.isStarred);
        }
        return file;
      }).toList();

      final newState = FileLoaded(updatedFiles);
      _lastLoadedState = newState;
      emit(newState);

      await fileRepository.saveFiles(updatedFiles);
    }
  }
}
