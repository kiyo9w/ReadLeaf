import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/widgets/snack_bar_widget.dart';
import 'package:migrated/blocs/FileBloc/file_bloc.dart';
import 'results_page.dart';
import '../depeninject/injection.dart';
import '../services/annas_archieve.dart';

final Map<String, String> typeValues = {
  'All': '',
  'Any Books': 'book_any',
  'Unknown Books': 'book_unknown',
  'Fiction Books': 'book_fiction',
  'Non-fiction Books': 'book_nonfiction',
  'Comic Books': 'book_comic',
  'Magazine': 'magazine',
  'Standards Document': 'standards_document',
  'Journal Article': 'journal_article'
};

final Map<String, String> sortValues = {
  'Most Relevant': '',
  'Newest': 'newest',
  'Oldest': 'oldest',
  'Largest': 'largest',
  'Smallest': 'smallest',
};

final List<String> fileType = ["All", "PDF", "Epub", "Cbr", "Cbz"];

final List<String> topSearchQueries = [
  "The 48 Laws of Power",
  "Atomic Habits",
  "Control Your Mind and Master Your Feelings"
];

final List<String> trendingQueries = [
  "fiction",
  "novel",
  "non-fiction",
  "romance"
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin{
  String searchQuery = "";
  String selectedType = "All";
  String selectedSort = "Most Relevant";
  String selectedFileType = "All";
  late final FileBloc _fileBloc;
  late final AnnasArchieve _annasArchieve;
  bool _isLoading = false;
  Map<String, List<BookData>>? _trendingBooks;
  Map<String, List<BookData>>? _topSearches;

  @override
  void initState() {
    super.initState();
    _fileBloc = getIt<FileBloc>();
    _annasArchieve = getIt<AnnasArchieve>();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final trendingFuture = _annasArchieve.getMassBooks(queries: trendingQueries);
      final topSearchesFuture = _annasArchieve.getMassBooks(queries: topSearchQueries);
      final results = await Future.wait([trendingFuture, topSearchesFuture]);
      setState(() {
        _trendingBooks = results[0];
        _topSearches = results[1];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching initial data: $e');
      setState(() => _isLoading = false);
    }
  }

  void onSubmit(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      _fileBloc.add(SearchBooks(
        query: searchQuery,
        content: typeValues[selectedType] ?? '',
        sort: sortValues[selectedSort] ?? '',
        fileType: selectedFileType == "All" ? '' : selectedFileType.toLowerCase(),
        enableFilters: true,
      ));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(searchQuery: searchQuery),
        ),
      );
    } else {
      showSnackBar(context: context, message: 'Search field is empty');
    }
  }

  Widget _buildTopSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Top searches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (_topSearches != null) ...[
          ..._topSearches!.entries.map((entry) {
            final query = entry.key;
            final books = entry.value;
            if (books.isEmpty) {
              return const SizedBox();
            }
            return ListTile(
              title: Text(books.first.title ?? query),
              subtitle: Text(books.first.author ?? 'Unknown author'),
              onTap: () {
                _fileBloc.add(SearchBooks(
                  query: query,
                  enableFilters: false,
                ));
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(searchQuery: query),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildTrending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Trending',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (_trendingBooks != null)
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _trendingBooks!.length,
              itemBuilder: (context, index) {
                final entry = _trendingBooks!.entries.elementAt(index);
                final books = entry.value;
                if (books.isEmpty) return const SizedBox();
                final book = books.first;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      _fileBloc.add(SearchBooks(
                        query: book.title ?? "",
                        enableFilters: false,
                      ));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultPage(searchQuery: book.title ?? ""),
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (book.thumbnail != null)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: Image.network(
                                book.thumbnail!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.book),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              height: 120,
                              color: Colors.grey[300],
                              child: const Icon(Icons.book),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              book.title ?? "Unknown",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileBloc, FileState>(
      bloc: _fileBloc,
      listener: (context, state) {
        if (state is FileError) {
          showSnackBar(context: context, message: state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            centerTitle: false,
            title: const Text(
              'Search',
              style: TextStyle(
                fontSize: 42.0,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: const EdgeInsets.only(right: 5),
                          color: Colors.black,
                          icon: const Icon(Icons.search, size: 23),
                          onPressed: () => onSubmit(context),
                        ),
                        Expanded(
                          child: TextField(
                            showCursor: true,
                            cursorColor: Colors.grey,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 15),
                              border: InputBorder.none,
                              hintText: "Find some books...",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onSubmitted: (_) => onSubmit(context),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            onChanged: (value) => setState(() => searchQuery = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _buildTopSearches(),
                  _buildTrending(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}