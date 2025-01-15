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
  final Map<String, bool> _expandedSections = {};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });

    _expandedSections['Genre'] = true;

    showModalBottomSheet(
      backgroundColor: const Color(0xFFF0F4FF),
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.3,
              maxChildSize: 0.80,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Filter",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildExpandableSection(
                                "Genre",
                                expanded: true,
                                onExpansionChanged: (isExpanded) {
                                  setModalState(() {});
                                },
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: SearchConstants.typeValues.keys
                                      .map((String type) {
                                    return _buildFilterChip(
                                      type,
                                      selected: selectedType == type,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          selectedType = type;
                                        });
                                        setState(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExpandableSection(
                                "Format",
                                expanded: false,
                                onExpansionChanged: (isExpanded) {
                                  setModalState(() {});
                                },
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: SearchConstants.fileTypes
                                      .map((String format) {
                                    return _buildFilterChip(
                                      format,
                                      selected: selectedFileType == format,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          selectedFileType = format;
                                        });
                                        setState(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExpandableSection(
                                "Sort by",
                                expanded: false,
                                onExpansionChanged: (isExpanded) {
                                  setModalState(() {});
                                },
                                child: Column(
                                  children: SearchConstants.sortValues.keys
                                      .map((String sort) {
                                    return _buildRadioTile(
                                      sort,
                                      selectedSort == sort,
                                      onChanged: (selected) {
                                        if (selected) {
                                          setModalState(() {
                                            selectedSort = sort;
                                          });
                                          setState(() {});
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExpandableSection(
                                "Ratings",
                                expanded: false,
                                onExpansionChanged: (isExpanded) {
                                  setModalState(() {});
                                },
                                child: Column(
                                  children: [
                                    _buildRatingTile(5),
                                    _buildRatingTile(4),
                                    _buildRatingTile(3),
                                    _buildRatingTile(2),
                                    _buildRatingTile(1),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildExpandableSection(
                                "Year Published",
                                expanded: false,
                                onExpansionChanged: (isExpanded) {
                                  setModalState(() {});
                                },
                                child: Column(
                                  children: [
                                    _buildYearRangeSlider(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      NavScreen.globalKey.currentState?.setNavBarVisibility(false);
    });
  }

  Widget _buildExpandableSection(
    String title, {
    required bool expanded,
    required Widget child,
    Function(bool)? onExpansionChanged,
  }) {
    _expandedSections[title] ??= expanded;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(title),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        trailing: Icon(
          _expandedSections[title] == true ? Icons.remove : Icons.add,
          color: Colors.pink,
        ),
        initiallyExpanded: _expandedSections[title] ?? expanded,
        onExpansionChanged: (isExpanded) {
          setState(() {
            _expandedSections[title] = isExpanded;
          });
          onExpansionChanged?.call(isExpanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: child,
          ),
        ],
      ),
    );
  }

  bool _isExpanded(String title) {
    return _expandedSections[title] ?? false;
  }

  Widget _buildFilterChip(String label,
      {bool selected = false, Function(bool)? onSelected}) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: Colors.pink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.pink : Colors.grey.shade300,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildRadioTile(String label, bool isSelected,
      {Function(bool)? onChanged}) {
    return RadioListTile<bool>(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.pink : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      value: true,
      groupValue: isSelected,
      onChanged: (bool? value) => onChanged?.call(value ?? false),
      activeColor: Colors.pink,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildRatingTile(int rating) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 20,
          ),
        ),
      ),
      title: Text('$rating Stars'),
      trailing: Checkbox(
        value: false,
        onChanged: (bool? value) {},
        activeColor: Colors.pink,
      ),
    );
  }

  Widget _buildYearRangeSlider() {
    return Column(
      children: [
        RangeSlider(
          values: const RangeValues(1990, 2024),
          min: 1900,
          max: 2024,
          divisions: 124,
          labels: const RangeLabels('1990', '2024'),
          onChanged: (RangeValues values) {},
          activeColor: Colors.pink,
          inactiveColor: Colors.grey.shade200,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1900', style: TextStyle(color: Colors.grey[600])),
              Text('2024', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ],
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
              key: const PageStorageKey('trending_list'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _trendingBooks!.length,
              itemBuilder: (context, index) {
                final entry = _trendingBooks!.entries.elementAt(index);
                final books = entry.value;
                if (books.isEmpty) return const SizedBox();
                final book = books.first;

                return RepaintBoundary(
                  child: Padding(
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
                                    key: ValueKey(book.thumbnail),
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
                                        key: ValueKey(book.thumbnail),
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
                            onPressed: () => {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    NavScreen.globalKey.currentState
                                        ?.setNavBarVisibility(true);
                                  }),
                                  _showFilterModal(context),
                                }),
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
