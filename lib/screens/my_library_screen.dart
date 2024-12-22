import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/widgets/file_card.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  bool _bookDownloadedExpanded = true;
  bool _favouriteExpanded = false;
  bool _localStorageExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBloc, FileState>(
      builder: (context, state) {
        List<dynamic> downloadedBooks = [];
        List<dynamic> starredBooks = [];
        List<dynamic> localFiles = [];

        if (state is FileLoaded) {
          downloadedBooks = state.files.map((f) {
            return {
              'filePath': f.filePath,
              'title': FileCard.extractFileName(f.filePath),
              'author': f.author,
              'size': f.fileSize,
              'isLocal': true,
              'isStarred': f.isStarred,
            };
          }).toList();

          starredBooks = downloadedBooks.where((book) => book['isStarred']).toList();
          localFiles = downloadedBooks;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 10, left: 10, right: 10, bottom: 10),
              child: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                title: const Text(
                  'My library',
                  style: TextStyle(
                    fontSize: 42.0,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryHeader(
                  title: "Book Downloaded",
                  count: downloadedBooks.length,
                  isExpanded: _bookDownloadedExpanded,
                  onTap: () {
                    setState(() {
                      _bookDownloadedExpanded = !_bookDownloadedExpanded;
                    });
                  },
                ),
                if (_bookDownloadedExpanded && downloadedBooks.isNotEmpty)
                  ..._buildBookCards(downloadedBooks),
                const SizedBox(height: 20),
                _buildCategoryHeader(
                  title: "Favourite",
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
        );
      },
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
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
              color: (count > 10) ? Color(0xffC5AA17) : (count > 5) ? Color(0xffEBD766) : (count > 0) ? Color(0xffFCF6D6) : Colors.white,
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
    );
  }

  List<Widget> _buildBookCards(List<dynamic> books) {
    return books.map((book) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: FileCard(
          filePath: book['filePath'],
          fileSize: book['size'],
          isSelected: false,
          onSelected: () {
            context.read<FileBloc>().add(SelectFile(book['filePath']));
          },
          onView: () {
            context.read<FileBloc>().add(ViewFile(book['filePath']));
          },
          onRemove: () {
            context.read<FileBloc>().add(RemoveFile(book['filePath']));
          },
          onDownload: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Already downloaded")),
            );
          },
          onStar: () {
            context.read<FileBloc>().add(ToggleStarred(book['filePath']));
          },
          title: book['title'],
          isInternetBook: !book['isLocal'],
          author: book['author'],
          thumbnailUrl: null,
          isStarred: book['isStarred'] ?? false,
        ),
      );
    }).toList();
  }
}
