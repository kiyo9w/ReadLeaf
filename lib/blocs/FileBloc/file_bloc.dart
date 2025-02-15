import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:read_leaf/models/file_info.dart';
import 'package:read_leaf/utils/file_utils.dart';
import 'package:read_leaf/services/storage_scanner_service.dart';
import 'package:read_leaf/services/rag_service.dart';
import 'package:read_leaf/injection.dart';

part 'file_event.dart';
part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  final FileRepository fileRepository;
  final StorageScannerService storageScannerService;
  final RagService _ragService = getIt<RagService>();

  FileBloc({
    required this.fileRepository,
    required this.storageScannerService,
  }) : super(FileInitial()) {
    on<InitFiles>(_onInitFiles);
    on<LoadFile>(_onLoadFile);
    on<SelectFile>(_onSelectFile);
    on<ViewFile>(_onViewFile);
    on<RemoveFile>(_onRemoveFile);
    on<CloseViewer>(_onCloseViewer);
    on<ToggleStarred>(_onToggleStarred);
    on<ToggleRead>(_onToggleRead);
    on<ScanStorage>(_onScanStorage);
  }

  Future<void> _onInitFiles(InitFiles event, Emitter<FileState> emit) async {
    print('Initializing files...');
    final savedFiles = await fileRepository.loadFiles();
    print('Loaded saved files: ${savedFiles.length}');

    if (savedFiles.isNotEmpty) {
      print('Using existing saved files');
      emit(FileLoaded(savedFiles));
    } else {
      print('No saved files found, copying default PDFs...');
      // Copy default PDFs and load them
      final defaultPdfPaths = await FileUtils.copyDefaultPDFs();
      print('Received paths for copied PDFs: $defaultPdfPaths');

      List<FileInfo> defaultFiles = [];

      for (String filePath in defaultPdfPaths) {
        try {
          print('Processing copied PDF at: $filePath');
          final file = File(filePath);
          if (await file.exists()) {
            final fileSize = await file.length();
            print('Adding file to defaultFiles: $filePath (size: $fileSize)');
            defaultFiles.add(FileInfo(filePath, fileSize));
          } else {
            print('File does not exist at path: $filePath');
          }
        } catch (e) {
          print('Error loading default PDF $filePath: $e');
        }
      }

      if (defaultFiles.isNotEmpty) {
        print('Saving ${defaultFiles.length} default files');
        await fileRepository.saveFiles(defaultFiles);
        emit(FileLoaded(defaultFiles));
      } else {
        print('No default files were loaded successfully');
        emit(FileInitial());
      }
    }
  }

  Future<void> _onLoadFile(LoadFile event, Emitter<FileState> emit) async {
    try {
      final filePath = event.filePath;
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File doesn\'t exist');
      }
      final fileSize = await file.length();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      }

      final isFileAlreadyLoaded =
          currentFiles.any((existingFile) => existingFile.filePath == filePath);

      if (!isFileAlreadyLoaded) {
        final fileType = FileParser.determineFileType(filePath);
        if (fileType == "pdf") {
          try {
            print('Uploading new PDF to backend: $filePath');
            await _ragService.uploadPdf(file);
            print('Successfully uploaded PDF to backend');
          } catch (e) {
            print('Error uploading PDF to backend: $e');
          }
        } else if (fileType == "epub") {
          print('Processing EPUB file: $filePath');
        }

        final newFiles = [...currentFiles, FileInfo(filePath, fileSize)];
        emit(FileLoaded(newFiles));
        await fileRepository.saveFiles(newFiles);
      } else {
        emit(FileLoaded(currentFiles));
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

      emit(FileLoaded(updatedFiles));
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  void _onViewFile(ViewFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final fileToView = currentState.files.firstWhere(
        (file) => file.filePath == event.filePath,
        orElse: () => currentState.files.first,
      );

      // Update wasRead status for all files
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(wasRead: true);
        }
        return file.copyWith(wasRead: false);
      }).toList();

      await fileRepository.saveFiles(updatedFiles);
      emit(FileViewing(updatedFiles, fileToView.filePath));
    }
  }

  Future<void> _onRemoveFile(RemoveFile event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentFiles = (state as FileLoaded).files;
      final updatedFiles = currentFiles
          .where((file) => file.filePath != event.filePath)
          .toList();

      if (updatedFiles.isEmpty) {
        emit(FileInitial());
        await fileRepository.saveFiles([]);
      } else {
        emit(FileLoaded(updatedFiles));
        await fileRepository.saveFiles(updatedFiles);
      }
    }
  }

  void _onCloseViewer(CloseViewer event, Emitter<FileState> emit) {
    if (state is FileViewing) {
      final fileViewingState = state as FileViewing;
      emit(FileLoaded(fileViewingState.files));
    }
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

      emit(FileLoaded(updatedFiles));
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  Future<void> _onToggleRead(ToggleRead event, Emitter<FileState> emit) async {
    if (state is FileLoaded) {
      final currentState = state as FileLoaded;
      final updatedFiles = currentState.files.map((file) {
        if (file.filePath == event.filePath) {
          return file.copyWith(hasBeenCompleted: !file.hasBeenCompleted);
        }
        return file;
      }).toList();

      emit(FileLoaded(updatedFiles));
      await fileRepository.saveFiles(updatedFiles);
    }
  }

  Future<void> _onScanStorage(
      ScanStorage event, Emitter<FileState> emit) async {
    try {
      emit(FileScanning());
      final discoveredFiles = await storageScannerService.scanStorage();

      List<FileInfo> currentFiles = [];
      if (state is FileLoaded) {
        currentFiles = (state as FileLoaded).files;
      }

      final Set<String> existingPaths =
          currentFiles.map((f) => f.filePath).toSet();
      final newFiles = [
        ...currentFiles,
        ...discoveredFiles
            .where((file) => !existingPaths.contains(file.filePath))
      ];

      emit(FileLoaded(newFiles));
      await fileRepository.saveFiles(newFiles);
    } catch (e) {
      emit(FileError(message: 'Storage scanning failed: ${e.toString()}'));
    }
  }
}
