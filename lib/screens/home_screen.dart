import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/file_utils.dart';
import '../blocs/FileBloc/bloc/file_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Read Leaf'),
        ),
        body: Center(
            child: ElevatedButton(
          onPressed: () async {
            final filePath = await FileUtils.picker();
            if (filePath != null) {
              context.read<FileBloc>().add(LoadFile(filePath));
              Navigator.pushNamed(context, '/viewer');
            }
          },
          child: const Text('Select a PDF file:'),
        )));
  }
}
