import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/home_screen.dart';
import 'screens/pdf_viewer.dart';
import 'blocs/FileBloc/file_bloc.dart';

void main() {
  runApp(MyApp());
}

// test test test
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FileBloc>(
          create: (context) => FileBloc(),
        ),
        // Add other bloc providers if needed
      ],
      child: MaterialApp(
        // your app configuration
        routes: {
          '/': (context) => HomeScreen(),
          '/viewer': (context) => PDFViewerScreen(),
        },
      ),
    );
  }
}