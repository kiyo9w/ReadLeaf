import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:migrated/widgets/snack_bar_widget.dart';
import 'package:migrated/blocs/SearchBloc/search_bloc.dart';
import 'package:migrated/screens/nav_screen.dart';
import 'package:migrated/constants/search_constants.dart';
import 'results_page.dart';
import 'package:migrated/injection.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavScreen.globalKey.currentState?.setNavBarVisibility(true);
    });

    _expandedSections['Genre'] = true;

    showModalBottomSheet(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
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
                              color:
                                  isDark ? Colors.grey[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Filter",
                                style: theme.textTheme.displayMedium,
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
                              const SizedBox(height: 50),
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
    final theme = Theme.of(context);
    _expandedSections[title] ??= expanded;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(title),
        title: Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        trailing: Icon(
          _expandedSections[title] == true ? Icons.remove : Icons.add,
          color: theme.primaryColor,
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

  Widget _buildFilterChip(
    String label, {
    required bool selected,
    required Function(bool) onSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: theme.primaryColor.withOpacity(0.2),
      backgroundColor: isDark ? theme.cardColor : Colors.grey[100],
      labelStyle: TextStyle(
        color: selected
            ? theme.primaryColor
            : (isDark ? Colors.white : Colors.black87),
      ),
      checkmarkColor: theme.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            selected ? BorderSide(color: theme.primaryColor) : BorderSide.none,
      ),
    );
  }

  Widget _buildRadioTile(
    String title,
    bool isSelected, {
    required Function(bool) onChanged,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyLarge,
      ),
      leading: Radio<bool>(
        value: true,
        groupValue: isSelected,
        onChanged: (value) => onChanged(value ?? false),
        activeColor: theme.primaryColor,
      ),
      onTap: () => onChanged(!isSelected),
    );
  }

  Widget _buildTopSearches() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Top searches',
            style: theme.textTheme.titleLarge,
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
              title: Text(
                books.first.title ?? query,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                books.first.author ?? 'Unknown author',
                style: theme.textTheme.bodyMedium,
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Trending',
            style: theme.textTheme.titleLarge,
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
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                                        return Center(
                                          child: CircularProgressIndicator(
                                            color: theme.primaryColor,
                                          ),
                                        );
                                      }
                                      if (snapshot.hasError ||
                                          !snapshot.hasData) {
                                        return Container(
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[300],
                                          child: Icon(
                                            Icons.book,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                          ),
                                        );
                                      }
                                      return Image(
                                        key: ValueKey(book.thumbnail),
                                        image: snapshot.data!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[300],
                                            child: Icon(
                                              Icons.book,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
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
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: Icon(
                                  Icons.book,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                book.title ?? "Unknown",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<SearchBloc, SearchState>(
      bloc: _searchBloc,
      listener: (context, state) {
        if (state is SearchError) {
          showSnackBar(context: context, message: state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            centerTitle: false,
            title: Text(
              'Search',
              style: theme.textTheme.displayLarge,
            ),
          ),
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? theme.cardColor : Colors.white54,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: const EdgeInsets.only(right: 5),
                            color: isDark ? Colors.white54 : Colors.grey,
                            icon: const Icon(Icons.search, size: 23),
                            onPressed: () => onSubmit(context),
                          ),
                          Expanded(
                            child: TextField(
                              onTap: () => {
                                NavScreen.globalKey.currentState
                                    ?.setNavBarVisibility(true)
                              },
                              autocorrect: false,
                              showCursor: true,
                              cursorColor:
                                  isDark ? Colors.white70 : Colors.grey,
                              decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                border: InputBorder.none,
                                hintText: "    Find some books...",
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onSubmitted: (_) => onSubmit(context),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onChanged: (value) =>
                                  setState(() => searchQuery = value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.filter_list),
                            color: isDark ? Colors.white54 : Colors.grey,
                            onPressed: () => {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                NavScreen.globalKey.currentState
                                    ?.setNavBarVisibility(true);
                              }),
                              _showFilterModal(context),
                            },
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
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
