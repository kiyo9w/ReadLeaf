import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../blocs/FileBloc/file_bloc.dart';

class PDFViewerScreen extends StatelessWidget {
  const PDFViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        if (state is FileViewing) {
          return Scaffold(
            appBar: AppBar(title: Text('title')),
            body: PDFView(
              filePath: state.filePath,
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