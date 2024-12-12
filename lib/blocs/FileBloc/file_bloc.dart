import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'dart:io';
import '../../models/file_info.dart';

part 'file_event.dart';
part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  FileBloc() : super(FileInitial()) {
    on<LoadFile>(_onLoadFile);
    on<SelectFile>(_onSelectFile);
    on<ViewFile>(_onViewFile);
    on<RemoveFile>(_onRemoveFile);
  }

  void _onLoadFile(LoadFile event, Emitter<FileState> emit) async {
    try {
      final filePath = event.filePath;
      final extension = filePath.split('.').last.toLowerCase();

      // Support more formats if needed
      if (!['pdf'].contains(extension)) {
        throw Exception('Unsupported file format');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File doesn\'t exist');
      }
      final fileSize = await file.length();

      // If the current state is FileLoaded, add to the list
      if (state is FileLoaded) {
        final currentFiles = (state as FileLoaded).files;
        final newFiles = [...currentFiles, FileInfo(filePath, fileSize)];
        emit(FileLoaded(newFiles));
      } else {
        // First file
        emit(FileLoaded([FileInfo(filePath, fileSize)]));
      }
    } catch (e) {
      emit(FileError(message: e.toString()));
    }
  }

  void _onSelectFile(SelectFile event, Emitter<FileState> emit) {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      emit(FileLoaded(
          currentState.files.map((file) =>
          file.filePath == event.filePath
              ? file.copyWith(isSelected: true)
              : file.copyWith(isSelected: false)
          ).toList()
      ));
    }
  }

  void _onViewFile(ViewFile event, Emitter<FileState> emit) {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final fileToView = currentState.files.firstWhere(
          (file) => file.filePath == event.filePath,
          orElse: () => currentState.files.first
      );
      emit(FileViewing(fileToView.filePath));
    }
  }

  void _onRemoveFile(RemoveFile event, Emitter<FileState> emit) {
    if (state is FileLoaded) {
      final currentFiles = (state as FileLoaded).files;
      final updatedFiles = currentFiles
          .where((file) => file.filePath != event.filePath)
          .toList();

      if (updatedFiles.isEmpty) {
        emit(FileInitial());
      } else {
        emit(FileLoaded(updatedFiles));
      }
    }
  }
}