import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/FileBloc/file_bloc.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerScreen extends StatelessWidget {
  const PDFViewerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileBloc = BlocProvider.of<FileBloc>(context);

    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        if (state is FileViewing) {
          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) {
              if (didPop) {
                fileBloc.add(CloseViewer());
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text('PDF Viewer'),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    fileBloc.add(CloseViewer());
                    Navigator.pop(context);
                  },
                ),
              ),
              body: SfPdfViewer.file(File(state.filePath)),
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