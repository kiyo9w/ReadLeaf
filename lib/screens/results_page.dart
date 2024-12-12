import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Project imports:
import '../blocs/FileBloc/file_bloc.dart';
import '../widgets/file_card.dart';
import '../widgets/page_title_widget.dart';

class ResultPage extends StatelessWidget {
  final String searchQuery;
  const ResultPage({Key? key, required this.searchQuery}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fileBloc = BlocProvider.of<FileBloc>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Openlib"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        titleTextStyle: Theme.of(context).textTheme.displayLarge,
      ),
      body: BlocBuilder<FileBloc, FileState>(
        builder: (context, state) {
          if (state is FileSearchLoading) {
            // Show a loading indicator while search results are being fetched.
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 5, right: 5, top: 10),
                  child: TitleText("Results"),
                ),
                const Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            );
          } else if (state is FileSearchResults) {
            final data = state.books;
            if (data.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
                child: CustomScrollView(
                  slivers: <Widget>[
                    const SliverToBoxAdapter(
                      child: TitleText("Results"),
                    ),
                    SliverList(
                        delegate: SliverChildListDelegate(
                          data.map((book) {
                            return FileCard(
                              filePath: book.link,      // Using the book link as a pseudo filePath
                              fileSize: 0,              // Unknown size, so just use 0
                              isSelected: false,        // No selection logic for search results
                              onSelected: () {
                                fileBloc.add(SelectFile(book.link));
                              },        // No action on long press
                              onView: () {
                                // Instead of navigating to BookInfoPage, just do nothing or show a message
                                fileBloc.add(ViewFile(book.link));
                              },
                              onRemove: () {},          // No remove action for search results
                              title: book.title,        // Show the book title
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            } else {
              // No results found
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Display a "no results" image if you have one
                    // For now, just show a text
                    const SizedBox(height: 30),
                    Text(
                      "No Results Found!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              );
            }
          } else if (state is FileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      BlocProvider.of<FileBloc>(context).add(SearchBooks(query: searchQuery));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No search initiated.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}