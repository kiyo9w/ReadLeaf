import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/screens/search_screen.dart';
import 'package:migrated/services/annas_archieve.dart';
import 'package:migrated/services/webview.dart';
import 'package:migrated/injection.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'package:migrated/blocs/SearchBloc/search_bloc.dart';
import 'package:migrated/widgets/file_card.dart';
import 'package:migrated/widgets/page_title_widget.dart';
import 'package:migrated/widgets/book_info_widget.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/services/thumbnail_service.dart';
import 'package:migrated/utils/file_utils.dart';
import 'package:migrated/utils/utils.dart';

class ResultPage extends StatefulWidget {
  final String searchQuery;

  const ResultPage({Key? key, required this.searchQuery}) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isShowingDownloadDialog = false;
  late final SearchBloc _searchBloc;
  late final FileBloc _fileBloc;
  late final AnnasArchieve annasArchieve;

  @override
  void initState() {
    super.initState();
    _searchBloc = getIt<SearchBloc>();
    _fileBloc = getIt<FileBloc>();
    annasArchieve = getIt<AnnasArchieve>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SearchBloc, SearchState>(
      bloc: _searchBloc,
      listener: (context, state) {
        if (state is SearchError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is DownloadComplete) {
          _fileBloc.add(LoadFile(state.filePath));
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Result',
                style: TextStyle(
                  fontSize: 42.0,
                ),
              ),
            ),
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(SearchState state) {
    if (state is SearchLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
            child: TitleText("Results for \"${widget.searchQuery}\""),
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
    }

    if (state is SearchResults) {
      final books = state.books;
      if (books.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: TitleText("Results for \"${widget.searchQuery}\""),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  books.map((book) {
                    return FileCard(
                      canDismiss: false,
                      filePath: book.link,
                      fileSize: 0,
                      isSelected: false,
                      onSelected: () {},
                      onView: () {
                        _handleBookClick(book.link);
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
                          _searchBloc.add(DownloadBook(
                            url: mirrorLink,
                            fileName: "${book.title}.pdf",
                          ));
                        } else {
                          Utils.showErrorSnackBar(
                              context, 'Failed to get download link');
                        }
                      },
                      onStar: () {},
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
      }
      return Center(
        child: Text(
          "No Results Found!",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.grey,
          ),
        ),
      );
    }

    if (state is SearchError) {
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
                _searchBloc.add(SearchBooks(query: widget.searchQuery));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const Center(child: Text('No content'));
  }

  Future<void> _handleBookClick(String url) async {
    await FileUtils.handleBookClick(
      url: url,
      context: context,
      searchBloc: _searchBloc,
      annasArchieve: annasArchieve,
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
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
    );
  }
}
