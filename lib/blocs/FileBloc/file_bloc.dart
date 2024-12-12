import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import '../../models/file_info.dart';
import '../../utils/file_utils.dart';

part 'file_event.dart';
part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  final FileRepository fileRepository;
  FileLoaded? _lastLoadedState; // Keep track of the last FileLoaded state

  FileBloc({required this.fileRepository}) : super(FileInitial()) {
    on<InitFiles>(_onInitFiles);
    on<LoadFile>(_onLoadFile);
    on<SelectFile>(_onSelectFile);
    on<ViewFile>(_onViewFile);
    on<RemoveFile>(_onRemoveFile);
    on<CloseViewer>(_onCloseViewer);
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

      if (!['pdf'].contains(extension)) {
        throw Exception('Unsupported file format');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File doesn\'t exist');
      }
      final fileSize = await file.length();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      }
      final newFiles = [...currentFiles, FileInfo(filePath, fileSize)];
      final newState = FileLoaded(newFiles);
      _lastLoadedState = newState;
      emit(newState);
      await fileRepository.saveFiles(newFiles);
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  Future<void> _onSelectFile(SelectFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) =>
      file.filePath == event.filePath
          ? file.copyWith(isSelected: true)
          : file.copyWith(isSelected: false)
      ).toList();
      final newState = FileLoaded(updatedFiles);
      _lastLoadedState = newState;
      emit(newState);
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  void _onViewFile(ViewFile event, Emitter<FileState> emit) {
    if (state is FileLoaded) {
      _lastLoadedState = state as FileLoaded;
      final fileToView = _lastLoadedState!.files.firstWhere(
              (file) => file.filePath == event.filePath,
          orElse: () => _lastLoadedState!.files.first
      );
      emit(FileViewing(fileToView.filePath));
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
    // When closing the viewer, revert back to the last known loaded state
    if (_lastLoadedState != null) {
      emit(_lastLoadedState!);
    } else {
      emit(FileInitial());
    }
  }
}