import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/widgets/file_card.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/models/file_info.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  bool _favouriteExpanded = true;
  bool _localStorageExpanded = true;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        _isScrollingDown = true;
        NavScreen.globalKey.currentState?.setNavBarVisibility(true);
      }
    }
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        _isScrollingDown = false;
        NavScreen.globalKey.currentState?.setNavBarVisibility(false);
      }
    }
  }

  Widget _buildCategoryHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (count > 10)
                  ? Color(0xffC5AA17)
                  : (count > 5)
                      ? Color(0xffEBD766)
                      : (count > 0)
                          ? Color(0xffFCF6D6)
                          : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.black,
          ),
        ],
      ),
    ),
    );
  }

  List<Widget> _buildBookCards(List<FileInfo> books) {
    return books.map((book) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FileCard(
          filePath: book.filePath,
          fileSize: book.fileSize,
          isSelected: book.isSelected,
          onSelected: () {
            context.read<FileBloc>().add(SelectFile(book.filePath));
          },
          onView: () {
            context.read<FileBloc>().add(ViewFile(book.filePath));
          },
          onRemove: () {
            context.read<FileBloc>().add(RemoveFile(book.filePath));
          },
          onDownload: () {},
          onStar: () {
            context.read<FileBloc>().add(ToggleStarred(book.filePath));
          },
          title: FileCard.extractFileName(book.filePath),
          isInternetBook: book.isInternetBook,
          author: book.author ?? 'Unknown',
          thumbnailUrl: book.thumbnailUrl,
          isStarred: book.isStarred,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        if (state is FileLoaded) {
          final starredBooks =
              state.files.where((file) => file.isStarred).toList();
          final localFiles =
              state.files.where((file) => !file.isStarred).toList();

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              centerTitle: false,
              title: const Text(
                'My Library',
                style: TextStyle(
                  fontSize: 42.0,
                ),
              ),
            ),
            body: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(
                      title: "Starred Books",
                      count: starredBooks.length,
                      isExpanded: _favouriteExpanded,
                      onTap: () {
                        setState(() {
                          _favouriteExpanded = !_favouriteExpanded;
                        });
                      },
                    ),
                    if (_favouriteExpanded && starredBooks.isNotEmpty)
                      ..._buildBookCards(starredBooks),
                    const SizedBox(height: 20),
                    _buildCategoryHeader(
                      title: "Local Storage",
                      count: localFiles.length,
                      isExpanded: _localStorageExpanded,
                      onTap: () {
                        setState(() {
                          _localStorageExpanded = !_localStorageExpanded;
                        });
                      },
                    ),
                    if (_localStorageExpanded && localFiles.isNotEmpty)
                      ..._buildBookCards(localFiles),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
