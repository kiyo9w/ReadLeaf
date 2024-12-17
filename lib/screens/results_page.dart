import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Project imports:
import '../blocs/FileBloc/file_bloc.dart';
import '../widgets/file_card.dart';
import '../widgets/page_title_widget.dart';

class ResultPage extends StatefulWidget {
  final String searchQuery;

  const ResultPage({Key? key, required this.searchQuery}) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isShowingDownloadDialog = false;

  @override
  Widget build(BuildContext context) {
    final fileBloc = BlocProvider.of<FileBloc>(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 10),
          child: AppBar(
            backgroundColor: Colors.white,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                fileBloc.add(CloseViewer());
                Navigator.pop(context);
              },
            ),
            title: const Text(
              'Result',
              style: TextStyle(
                fontSize: 42.0,
              ),
            ),
          ),
        ),
      ),
      body: BlocConsumer<FileBloc, FileState>(
        listener: (context, state) {
          if (state is FileViewing) {
            if (_isShowingDownloadDialog) {
              Navigator.pop(context);
              _isShowingDownloadDialog = false;
            }
            Navigator.pushNamed(context, '/viewer').then((_) {
              Navigator.pop(context);
            });
          } else if (state is FileDownloading) {
            // Show or update the download progress dialog
            if (!_isShowingDownloadDialog) {
              _isShowingDownloadDialog = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => DownloadProgressDialog(progress: state.progress),
              );
            } else {
              // If dialog already showing, update the state
              Navigator.pop(context); // pop old dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => DownloadProgressDialog(progress: state.progress),
              );
            }
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
                            onDownload: () {
                              fileBloc.add(DownloadFile(url: book.link, fileName: 'test.pdf'));
                            },
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
                      fileBloc.add(SearchBooks(query: widget.searchQuery));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    style: TextStyle(fontSize: 16),
                    '$state',
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

class DownloadProgressDialog extends StatelessWidget {
  final double progress;

  const DownloadProgressDialog({Key? key, required this.progress})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toStringAsFixed(0);
    return AlertDialog(
      title: Text('Downloading...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          SizedBox(height: 10),
          Text('$percentage%'),
        ],
      ),
    );
  }
}