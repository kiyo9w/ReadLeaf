import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'dart:io';

part 'file_event.dart';
part 'file_state.dart';

class FileBloc extends Bloc<FileEvent, FileState> {
  FileBloc() : super(FileInitial()) {
    @override
    Stream<FileState> mapEventToState(FileEvent event) async* {
      if (event is LoadFile) {
        yield FileLoading();
        try {
          final filePath = event.filePath;
          if (!['pdf'].contains(event.filePath.split('.').last.toLowerCase())) {
            throw Exception('Unsported file format');
          }

          final file = File(filePath);
          if (!await file.exists()) {
            throw Exception('File doesnt exist');
          }
          final fileSize = await file.length();

          yield FileLoaded(filePath, fileSize);
        } catch (e) {
          yield FileError(message: e.toString());
        }
      }
    }
  }
}
