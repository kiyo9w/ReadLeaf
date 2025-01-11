import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/widgets/snack_bar_widget.dart';
import 'package:migrated/blocs/SearchBloc/search_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/constants/search_constants.dart';
import 'results_page.dart';
import '../depeninject/injection.dart';
import '../services/annas_archieve.dart';
import 'package:migrated/services/thumbnail_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  String searchQuery = "";
  String selectedType = "All";
  String selectedSort = "Most Relevant";
  String selectedFileType = "All";
  late final SearchBloc _searchBloc;
  late final AnnasArchieve _annasArchieve;
  bool _isLoading = false;
  Map<String, List<BookData>>? _trendingBooks;
  Map<String, List<BookData>>? _topSearches;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _searchBloc = getIt<SearchBloc>();
    _annasArchieve = getIt<AnnasArchieve>();
    _fetchInitialData();
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

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final trendingFuture =
          _annasArchieve.getMassBooks(queries: SearchConstants.trendingQueries);
      final topSearchesFuture = _annasArchieve.getMassBooks(
          queries: SearchConstants.topSearchQueries);
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
      _searchBloc.add(SearchBooks(
        query: searchQuery,
        content: SearchConstants.typeValues[selectedType] ?? '',
        sort: SearchConstants.sortValues[selectedSort] ?? '',
        fileType:
            selectedFileType == "All" ? '' : selectedFileType.toLowerCase(),
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

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Filters",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                    value: selectedType,
                    items: SearchConstants.typeValues.keys
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setModalState(() {
                        selectedType = val ?? 'All';
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                    value: selectedSort,
                    items: SearchConstants.sortValues.keys
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setModalState(() {
                        selectedSort = val ?? 'Most Relevant';
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(
                      labelText: 'File type',
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                    value: selectedFileType,
                    items: SearchConstants.fileTypes
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      setModalState(() {
                        selectedFileType = val ?? 'All';
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                _searchBloc.add(SearchBooks(
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
                      _searchBloc.add(SearchBooks(
                        query: book.title ?? "",
                        enableFilters: false,
                      ));
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ResultPage(searchQuery: book.title ?? ""),
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
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                              child: SizedBox(
                                height: 120,
                                width: 120,
                                child: FutureBuilder<ImageProvider>(
                                  future: ThumbnailService()
                                      .getNetworkThumbnail(book.thumbnail!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError ||
                                        !snapshot.hasData) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.book),
                                      );
                                    }
                                    return Image(
                                      image: snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.book),
                                        );
                                      },
                                    );
                                  },
                                ),
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
    return BlocConsumer<SearchBloc, SearchState>(
      bloc: _searchBloc,
      listener: (context, state) {
        if (state is SearchError) {
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
            controller: _scrollController,
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
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 15),
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
                            onChanged: (value) =>
                                setState(() => searchQuery = value),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          color: Colors.black54,
                          onPressed: () => _showFilterModal(context),
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
