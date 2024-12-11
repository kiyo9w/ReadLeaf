import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/home_screen.dart';
import 'screens/pdf_viewer.dart';
import 'blocs/FileBloc/file_bloc.dart';

void main() {
  runApp(const MyApp());
}

// test test test
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Reader',
      routes: {
        '/': (context) => BlocProvider(
              create: (_) => FileBloc(),
              child: const HomeScreen(),
            ),
        '/viewer': (context) => const PDFViewerScreen(),
      },
      initialRoute: '/',
    );
  }
}