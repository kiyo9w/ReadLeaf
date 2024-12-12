import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../blocs/FileBloc/file_bloc.dart';
import '../widgets/file_card.dart';
import '../utils/file_utils.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fileBloc = BlocProvider.of<FileBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Reader'),
      ),
      body: BlocBuilder<FileBloc, FileState>(
        builder: (context, state) {
          if (state is FileInitial) {
            return const Center(child: Text('No files loaded.'));
          } else if (state is FileLoaded) {
            return ListView.builder(
              itemCount: state.files.length,
              itemBuilder: (context, index) {
                final file = state.files[index];
                return FileCard(
                  filePath: file.filePath,
                  fileSize: file.fileSize,
                  isSelected: file.isSelected,
                  onSelected: () {
                    fileBloc.add(SelectFile(file.filePath));
                  },
                  onView: () {
                    fileBloc.add(ViewFile(file.filePath));
                  },
                  onRemove: () {
                    fileBloc.add(RemoveFile(file.filePath));
                  },
                );
              },
            );
          } else if (state is FileError) {
            return Center(child: Text('Error: ${state.message}'));
          } else {
            return const Center(child: Text('Unexpected state'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final filePath = await FileUtils.picker();
          if (filePath != null) {
            fileBloc.add(LoadFile(filePath));
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Add File',
      ),
    );
  }
}