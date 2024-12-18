import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/services/annas_archieve.dart';
import '../services/webview.dart';

// Project imports:
import '../blocs/FileBloc/file_bloc.dart';
import '../widgets/file_card.dart';
import '../widgets/page_title_widget.dart';
import '../widgets/book_info_widget.dart';

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
      body: BlocConsumer<FileBloc, FileState>(
        listener: (context, state) {
          if (state is FileViewing) {
            Navigator.pushNamed(context, '/viewer').then((_) {
              Navigator.pop(context);
            });
          }
        },
        builder: (context, state) {
          if (state is FileSearchLoading) {
            return Column(
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
                              fileBloc.add(LoadBookInfo(book.link));
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Color(0xffEBE6E0),
                                builder: (ctx) {
                                    return BookInfoWidget(
                                      genre: AnnasArchieve.getGenreFromInfo(book.info!),
                                      thumbnailUrl: book.thumbnail,
                                      author: book.author,
                                      link: book.link,
                                      description: book.description,
                                      fileSize: AnnasArchieve.getFileSizeFromInfo(book.info!),
                                      title: book.title,
                                      ratings: 4,
                                      language: AnnasArchieve.getLanguageFromInfo(book.info!),
                                      onDownload: () async {
                                        final mirrorLink = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => WebviewPage(url: book.link),
                                          ),
                                        );

                                        if (mirrorLink != null && mirrorLink is String) {
                                          fileBloc.add(DownloadFile(url: mirrorLink, fileName: 'test.pdf'));
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to get download link')),
                                          );
                                        }
                                      },
                                    );
                                },
                              );
                              },
                            onRemove: () {},
                            onDownload: () async {
                              final mirrorLink = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WebviewPage(url: book.link),
                                ),
                              );

                              if (mirrorLink != null && mirrorLink is String) {
                                fileBloc.add(DownloadFile(url: mirrorLink, fileName: 'test.pdf'));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to get download link')),
                                );
                              }
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