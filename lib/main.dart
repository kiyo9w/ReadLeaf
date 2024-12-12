import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/home_screen.dart';
import 'screens/pdf_viewer.dart';
import 'blocs/FileBloc/file_bloc.dart';
import 'utils/file_utils.dart';

void main() {
  final fileRepository = FileRepository();
  runApp(MyApp(fileRepository: fileRepository));
}

class MyApp extends StatelessWidget {
  final FileRepository fileRepository;

  const MyApp({Key? key, required this.fileRepository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FileBloc>(
          create: (context) => FileBloc(fileRepository: fileRepository)
            ..add(InitFiles()), // Load saved files on startup
        ),
      ],
      child: MaterialApp(
        routes: {
          '/': (context) => const HomeScreen(),
          '/viewer': (context) => const PDFViewerScreen(),
        },
      ),
    );
  }
}