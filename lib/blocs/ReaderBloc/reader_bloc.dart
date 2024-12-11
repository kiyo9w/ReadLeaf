import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:migrated/blocs/FileBloc/bloc/file_bloc.dart';

part 'reader_event.dart';
part 'reader_state.dart';

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc() : super(ReaderInitial());

  @override
  Stream<ReaderState> mapEventToState(ReaderEvent event) async* {
    if (event is OpenReader) {
      yield ReaderLoading();
      try {
        final File file = event.file;
        if (await file.exists()) {
          final fileType = determineFileType(event.filePath);
          yield ReaderLoaded(null,file: event.file);
        } else {
          yield ReaderError("File not found.");
        }
      } catch (e) {
        yield ReaderError(e.toString());
      }
    } else if (event is ParseFile) {
      yield ReaderLoading();
      try {
        final fileType = determineFileType(event.file.path);
        final parsedContent = await parseFile(event.file, fileType); // Implement parser
        yield ReaderLoaded(parsedContent, file: event.file);
      } catch (e) {
        yield ReaderError(e.toString());
      }
    } else if (event is CloseReader) {
      yield ReaderInitial();
    }
  }

  String determineFileType(String filePath) {
    if (filePath.endsWith(".pdf")) return "pdf";
    if (filePath.endsWith(".mobi")) return "mobi";
    if (filePath.endsWith(".md")) return "markdown";
    return "unknown";
  }

  Future<dynamic> parseFile(File file, String fileType) async {
    dynamic content;
    if (fileType == "pdf") {
      // logic
    } else if (fileType == "mobi") {
      // logic
    } else if (fileType == "markdown") {
      // logic
    } else {
      content = "Can't read unsupported format file";
    }
    return content;
  }
}