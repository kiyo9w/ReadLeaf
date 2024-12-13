import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/DownloadBloc/download_bloc.dart';
import '../blocs/FileBloc/file_bloc.dart';
import '../widgets/file_card.dart';

class MyLibraryScreen extends StatelessWidget {
  const MyLibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // return BlocBuilder<FileBloc, FileState>(
    //   builder: (context, state) {
    //     if (state is FileLoaded) {
    //       final files = state.files;
    //       if (files.isEmpty) {
    //         return const Center(child: Text('No downloaded files.'));
    //       }
    //       return ListView.builder(
    //         itemCount: files.length,
    //         itemBuilder: (context, index) {
    //           final file = files[index];
    //           return FileCard(
    //             filePath: file.filePath,
    //             fileSize: file.fileSize,
    //             isSelected: file.isSelected,
    //             title: FileCard.extractFileName(file.filePath),
    //             onSelected: () {},
    //             onView: () {
    //               BlocProvider.of<FileBloc>(context).add(ViewFile(file.filePath));
    //             },
    //             onRemove: () {
    //               BlocProvider.of<FileBloc>(context).add(RemoveFile(file.filePath));
    //             },
    //           );
    //         },
    //       );
    //     } else if (state is DownloadInProgress) {
    //       return Center(child: Text("in progess"));
    //     } else if (state is DownloadCompleted) {
    //       return Center(child: Text("Download Completed"));
    //     } else if (state is DownloadFailed) {
    //       return Center(child: Text("Download Failed"));
    //     } else if (state is FileError) {
    //       return Center(child: Text('Error: ${state.message}'));
    //     } else {
    //       return const Center(child: Text('No files.'));
    //     }
    //   },
    //);
    return const Center(child: Text('Downloaded Books Screen'));
  }
}