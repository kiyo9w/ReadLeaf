import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:synchronized/extension.dart';
import 'package:read_leaf/constants/responsive_constants.dart';

class TextSearchView extends StatefulWidget {
  const TextSearchView({
    super.key,
    required this.textSearcher,
    required this.onClose,
  });

  final PdfTextSearcher textSearcher;
  final VoidCallback onClose;

  @override
  State<TextSearchView> createState() => _TextSearchViewState();
}

class _TextSearchViewState extends State<TextSearchView> {
  final focusNode = FocusNode();
  final searchTextController = TextEditingController();
  late final pageTextStore =
      PdfPageTextCache(textSearcher: widget.textSearcher);
  final scrollController = ScrollController();
  static const int initialResultLimit = 500;
  bool _showAllResults = false;

  @override
  void initState() {
    super.initState();
    widget.textSearcher.addListener(_searchResultUpdated);
    searchTextController.addListener(_searchTextUpdated);
  }

  void _clearSearch() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      searchTextController.clear();
      widget.textSearcher.resetTextSearch();
      _matchIndexToListIndex.clear();
      _listIndexToMatchIndex.clear();
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.textSearcher.resetTextSearch();
    });

    scrollController.dispose();
    widget.textSearcher.removeListener(_searchResultUpdated);
    searchTextController.removeListener(_searchTextUpdated);
    searchTextController.dispose();
    focusNode.dispose();
    _matchIndexToListIndex.clear();
    _listIndexToMatchIndex.clear();
    super.dispose();
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.textSearcher.resetTextSearch();
      _matchIndexToListIndex.clear();
      _listIndexToMatchIndex.clear();
    });
    super.deactivate();
  }

  void _searchTextUpdated() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAllResults = false;
      widget.textSearcher.startTextSearch(searchTextController.text);
    });
  }

  int? _currentSearchSession;
  final _matchIndexToListIndex = <int>[];
  final _listIndexToMatchIndex = <int>[];

  int get _effectiveMatchCount {
    final totalMatches = widget.textSearcher.matches.length;
    return _showAllResults
        ? totalMatches
        : totalMatches.clamp(0, initialResultLimit);
  }

  void _searchResultUpdated() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentSearchSession != widget.textSearcher.searchSession) {
        _currentSearchSession = widget.textSearcher.searchSession;
        _matchIndexToListIndex.clear();
        _listIndexToMatchIndex.clear();
        _showAllResults = false;
      }

      final effectiveCount = _effectiveMatchCount;
      for (int i = _matchIndexToListIndex.length; i < effectiveCount; i++) {
        if (i == 0 ||
            widget.textSearcher.matches[i - 1].pageNumber !=
                widget.textSearcher.matches[i].pageNumber) {
          _listIndexToMatchIndex
              .add(-widget.textSearcher.matches[i].pageNumber);
        }
        _matchIndexToListIndex.add(_listIndexToMatchIndex.length);
        _listIndexToMatchIndex.add(i);
      }

      setState(() {});
    });
  }

  static const double itemHeight = 80;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 8,
      child: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF251B2F).withOpacity(0.98)
            : const Color(0xFFFAF9F7).withOpacity(0.98),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveConstants.isTablet(context) ? 24 : 16,
                  vertical: ResponsiveConstants.isTablet(context) ? 16 : 12,
                ),
                child: Row(
                  children: [
                    Text(
                      'Search Results',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF2F2F7)
                            : const Color(0xFF1C1C1E),
                        fontSize: ResponsiveConstants.getTitleFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: ResponsiveConstants.getIconSize(context),
                        minHeight: ResponsiveConstants.getIconSize(context),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6E6E73),
                        size: ResponsiveConstants.getIconSize(context),
                      ),
                      onPressed: () {
                        _clearSearch();
                        widget.onClose();
                      },
                    ),
                  ],
                ),
              ),
              widget.textSearcher.isSearching
                  ? LinearProgressIndicator(
                      value: widget.textSearcher.searchProgress,
                      minHeight: 4,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF352A3B)
                              : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFAA96B6)
                              : const Color(0xFF9E7B80)),
                    )
                  : const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF8F1F1),
                    ),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  autofocus: false,
                  focusNode: focusNode,
                  controller: searchTextController,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF2F2F7)
                        : const Color(0xFF1C1C1E),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search in document',
                    hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6E6E73),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF352A3B)
                        : const Color(0xFFF8F1F1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFAA96B6)
                            : const Color(0xFF9E7B80),
                        width: 1,
                      ),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.textSearcher.hasMatches)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${widget.textSearcher.currentIndex! + 1} / ${widget.textSearcher.matches.length}',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF6E6E73),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (searchTextController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF8E8E93)
                                  : const Color(0xFF6E6E73),
                              size: 20,
                            ),
                            onPressed: () {
                              searchTextController.clear();
                              widget.textSearcher.resetTextSearch();
                              focusNode.requestFocus();
                            },
                          ),
                      ],
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF352A3B).withOpacity(0.5)
                      : const Color(0xFFF8F1F1).withOpacity(0.5),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          key: Key(searchTextController.text),
                          controller: scrollController,
                          itemCount: _listIndexToMatchIndex.isEmpty
                              ? 0
                              : _listIndexToMatchIndex.length,
                          itemBuilder: (context, index) {
                            if (_listIndexToMatchIndex.isEmpty) return null;

                            final matchIndex = _listIndexToMatchIndex[index];
                            if (matchIndex >= 0 &&
                                matchIndex < _effectiveMatchCount) {
                              final match =
                                  widget.textSearcher.matches[matchIndex];
                              return SearchResultTile(
                                key: ValueKey(index),
                                match: match,
                                onTap: () async {
                                  await widget.textSearcher
                                      .goToMatchOfIndex(matchIndex);
                                  if (mounted) setState(() {});
                                },
                                pageTextStore: pageTextStore,
                                height: itemHeight,
                                isCurrent: matchIndex ==
                                    widget.textSearcher.currentIndex,
                                isDark: isDark,
                              );
                            } else if (matchIndex < 0) {
                              return Container(
                                height: itemHeight,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text(
                                  'Page ${-matchIndex}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      if (!_showAllResults &&
                          widget.textSearcher.matches.length >
                              initialResultLimit)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAllResults = true;
                                _searchResultUpdated();
                              });
                            },
                            icon: Icon(
                              Icons.expand_more,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            label: Text(
                              'Show More (${widget.textSearcher.matches.length - initialResultLimit} more results)',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchResultTile extends StatefulWidget {
  const SearchResultTile({
    super.key,
    required this.match,
    required this.onTap,
    required this.pageTextStore,
    required this.height,
    required this.isCurrent,
    required this.isDark,
  });

  final PdfTextRangeWithFragments match;
  final void Function() onTap;
  final PdfPageTextCache pageTextStore;
  final double height;
  final bool isCurrent;
  final bool isDark;

  @override
  State<SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<SearchResultTile> {
  PdfPageText? pageText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _release() {
    if (pageText != null) {
      widget.pageTextStore.releaseText(pageText!.pageNumber);
    }
  }

  Future<void> _load() async {
    _release();
    pageText = await widget.pageTextStore.loadText(widget.match.pageNumber);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      createTextSpanForMatch(pageText, widget.match),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    return SizedBox(
      height: widget.height,
      child: Material(
        color: widget.isCurrent
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF352A3B)
                : const Color(0xFFF8F1F1))
            : Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTap(),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF8F1F1),
                  width: 0.5,
                ),
              ),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: text,
          ),
        ),
      ),
    );
  }

  TextSpan createTextSpanForMatch(
      PdfPageText? pageText, PdfTextRangeWithFragments match,
      {TextStyle? style}) {
    style ??= TextStyle(
      fontSize: 14,
      color: widget.isDark ? Colors.white : Colors.black,
      height: 1.2,
    );
    if (pageText == null) {
      return TextSpan(
        text: match.fragments.map((f) => f.text).join(),
        style: style,
      );
    }
    final fullText = pageText.fullText;
    int first = 0;
    for (int i = match.fragments.first.index - 1; i >= 0;) {
      if (fullText[i] == '\n') {
        first = i + 1;
        break;
      }
      i--;
    }
    int last = fullText.length;
    for (int i = match.fragments.last.end; i < fullText.length; i++) {
      if (fullText[i] == '\n') {
        last = i;
        break;
      }
    }

    final header =
        fullText.substring(first, match.fragments.first.index + match.start);
    final body = fullText.substring(match.fragments.first.index + match.start,
        match.fragments.last.index + match.end);
    final footer =
        fullText.substring(match.fragments.last.index + match.end, last);

    return TextSpan(
      children: [
        TextSpan(
          text: header,
          style: style.copyWith(
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        TextSpan(
          text: body,
          style: style.copyWith(
            backgroundColor: widget.isDark
                ? const Color(0xFF9C27B0).withOpacity(0.3)
                : Colors.yellow.withOpacity(0.3),
            color: widget.isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: footer,
          style: style.copyWith(
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class PdfPageTextCache {
  final PdfTextSearcher textSearcher;
  PdfPageTextCache({
    required this.textSearcher,
  });

  final _pageTextRefs = <int, _PdfPageTextRefCount>{};

  Future<PdfPageText> loadText(int pageNumber) async {
    final ref = _pageTextRefs[pageNumber];
    if (ref != null) {
      ref.refCount++;
      return ref.pageText;
    }
    return await synchronized(() async {
      var ref = _pageTextRefs[pageNumber];
      if (ref == null) {
        final pageText = await textSearcher.loadText(pageNumber: pageNumber);
        ref = _pageTextRefs[pageNumber] = _PdfPageTextRefCount(pageText!);
      }
      ref.refCount++;
      return ref.pageText;
    });
  }

  void releaseText(int pageNumber) {
    final ref = _pageTextRefs[pageNumber]!;
    ref.refCount--;
    if (ref.refCount == 0) {
      _pageTextRefs.remove(pageNumber);
    }
  }
}

class _PdfPageTextRefCount {
  _PdfPageTextRefCount(this.pageText);
  final PdfPageText pageText;
  int refCount = 0;
}
