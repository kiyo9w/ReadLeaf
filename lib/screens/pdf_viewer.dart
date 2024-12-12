import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/FileBloc/file_bloc.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerScreen extends StatelessWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

  bool _isInternetBook(String filePath) {
    return filePath.startsWith('http://') || filePath.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final fileBloc = BlocProvider.of<FileBloc>(context);

    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        if (state is FileViewing) {
          final isInternetBook = _isInternetBook(state.filePath);
          return WillPopScope(
            onWillPop: () async {
              fileBloc.add(CloseViewer());
              return true;
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text('PDF Viewer'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    fileBloc.add(CloseViewer());
                    Navigator.pop(context);
                  },
                ),
              ),
              body: isInternetBook
                  ? SfPdfViewer.network(state.filePath)
                  : SfPdfViewer.file(File(state.filePath)),
            ),
          );
        } else if (state is FileError) {
          return Center(child: Text('Error: ${state.message}'));
        } else {
          return const Center(child: Text('Please select a PDF'));
        }
      },
    );
  }
}