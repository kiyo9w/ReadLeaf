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
      // Use BlocConsumer instead of BlocBuilder to also have a listener
      body: BlocConsumer<FileBloc, FileState>(
        listener: (context, state) {
          // If FileViewing state is emitted, navigate to /viewer
          if (state is FileViewing) {
            Navigator.pushNamed(context, '/viewer');
          }
        },
        builder: (context, state) {
          if (state is FileSearchLoading) {
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
                            filePath: book.link,
                            fileSize: 0,
                            isSelected: false,
                            onSelected: () {
                              fileBloc.add(SelectFile(book.link));
                            },
                            onView: () {
                              fileBloc.add(ViewFile(book.link));
                            },
                            onRemove: () {},
                            title: book.title,
                            isInternetBook: true,
                            author: book.author,
                            thumbnailUrl: book.thumbnail,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      fileBloc.add(SearchBooks(query: searchQuery));
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