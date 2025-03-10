import 'package:dio/dio.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:read_leaf/core/constants/responsive_constants.dart';

enum SelectionMenuType {
  askAi,
  translate,
  highlight,
  dictionary,
  wikipedia,
  audio,
  generateImage,
}

class FloatingSelectionMenu extends StatefulWidget {
  final String? selectedText;
  final Function(SelectionMenuType, String) onMenuSelected;
  final VoidCallback? onDismiss;
  final VoidCallback? onExpand;
  final bool displayAtTop;

  const FloatingSelectionMenu({
    super.key,
    required this.selectedText,
    required this.onMenuSelected,
    this.onDismiss,
    this.onExpand,
    this.displayAtTop = false,
  });

  @override
  State<FloatingSelectionMenu> createState() => _FloatingSelectionMenuState();
}

class _FloatingSelectionMenuState extends State<FloatingSelectionMenu> {
  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentPageIndex = 0;

  late final List<SelectionMenuType> _availableMenus;

  bool _dictionaryLoading = false;
  String? _dictionaryError;
  String _dictionaryWord = '';
  String _dictionaryPhonetic = '';
  List<String> _dictionaryDefinitions = [];

  bool _wikiLoading = false;
  String? _wikiError;
  String _wikiExtract = '';

  // Add request cancellation tokens
  Dio? _dictionaryDio;
  Dio? _wikiDio;
  CancelToken? _dictionaryCancelToken;
  CancelToken? _wikiCancelToken;

  @override
  void initState() {
    super.initState();
    final String selectionText = widget.selectedText ?? '';
    final int wordCount = selectionText.trim().split(RegExp(r'\s+')).length;

    final allMenus = [
      SelectionMenuType.askAi,
      SelectionMenuType.translate,
      SelectionMenuType.dictionary,
      SelectionMenuType.wikipedia,
      SelectionMenuType.generateImage,
    ];

    // Highlight and audio are now outside the floating menu
    // Filter menus based on word count
    if (wordCount > 4) {
      allMenus.remove(SelectionMenuType.dictionary);
      allMenus.remove(SelectionMenuType.wikipedia);
    }
    _availableMenus = allMenus;

    // Set up page change listener
    _pageController.addListener(() {
      final page = (_pageController.page ?? 0).round();
      if (_currentPageIndex != page) {
        if (mounted) {
          setState(() {
            _currentPageIndex = page;
          });
        }
      }
    });

    if (_availableMenus.contains(SelectionMenuType.dictionary) &&
        selectionText.isNotEmpty) {
      _fetchDictionaryData(selectionText);
    }

    if (_availableMenus.contains(SelectionMenuType.wikipedia) &&
        selectionText.isNotEmpty) {
      _fetchWikipediaData(selectionText);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Cancel any pending API requests
    _dictionaryCancelToken?.cancel("Widget disposed");
    _wikiCancelToken?.cancel("Widget disposed");
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DICTIONARY API (dictionaryapi.dev, English only)
  // ---------------------------------------------------------------------------
  Future<void> _fetchDictionaryData(String word) async {
    if (!mounted) return;

    setState(() {
      _dictionaryLoading = true;
      _dictionaryError = null;
      _dictionaryWord = '';
      _dictionaryPhonetic = '';
      _dictionaryDefinitions = [];
    });

    // Cancel previous request if any
    _dictionaryCancelToken?.cancel("New request made");
    _dictionaryCancelToken = CancelToken();
    _dictionaryDio = Dio();

    _dictionaryDio!.options.validateStatus = (status) {
      return true;
    };

    try {
      final url = 'https://api.dictionaryapi.dev/api/v2/entries/en/$word';
      final response = await _dictionaryDio!.get(
        url,
        cancelToken: _dictionaryCancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      // Check if widget is still mounted before processing the response
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (data.isNotEmpty) {
          final firstEntry = data[0] as Map<String, dynamic>;

          _dictionaryWord = (firstEntry['word'] ?? '').toString();

          final phonetics = firstEntry['phonetics'] as List<dynamic>?;
          if (phonetics != null && phonetics.isNotEmpty) {
            final phoneticObj = phonetics.first as Map<String, dynamic>;
            if (phoneticObj['text'] != null) {
              _dictionaryPhonetic = phoneticObj['text'];
            }
          }

          final meanings = firstEntry['meanings'] as List<dynamic>?;
          if (meanings != null) {
            for (final meaning in meanings) {
              final meaningMap = meaning as Map<String, dynamic>;
              final partOfSpeech = meaningMap['partOfSpeech'] ?? '';
              final defs = meaningMap['definitions'] as List<dynamic>?;

              if (defs != null) {
                for (final def in defs) {
                  final defMap = def as Map<String, dynamic>;
                  final definitionText = defMap['definition'] ?? '';
                  if (definitionText.toString().isNotEmpty) {
                    _dictionaryDefinitions
                        .add('$partOfSpeech: $definitionText');
                  }
                }
              }
            }
          }
        } else {
          _dictionaryError = 'No dictionary data found.';
        }
      } else {
        _dictionaryError = 'No dictionary entry found for "$word".';
      }
    } catch (e) {
      if (!mounted) return;
      _dictionaryError = 'Dictionary error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _dictionaryLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // WIKIPEDIA API (English by default)
  // ---------------------------------------------------------------------------
  Future<void> _fetchWikipediaData(String topic) async {
    if (!mounted) return;

    setState(() {
      _wikiLoading = true;
      _wikiError = null;
      _wikiExtract = '';
    });

    // Cancel previous request if any
    _wikiCancelToken?.cancel("New request made");
    _wikiCancelToken = CancelToken();
    _wikiDio = Dio();

    _wikiDio!.options.validateStatus = (status) {
      return true;
    };

    try {
      final url = 'https://en.wikipedia.org/w/api.php?action=query'
          '&prop=extracts&explaintext&format=json&redirects=1&titles=$topic';

      final response = await _wikiDio!.get(
        url,
        cancelToken: _wikiCancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      // Check if widget is still mounted before processing the response
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['query'] != null && data['query']['pages'] != null) {
          final pages = data['query']['pages'] as Map<String, dynamic>;
          if (pages.isNotEmpty) {
            final pageId = pages.keys.first;
            final pageData = pages[pageId] as Map<String, dynamic>;
            final extract = pageData['extract']?.toString() ?? '';
            if (extract.isNotEmpty) {
              final snippet = extract.length > 500
                  ? '${extract.substring(0, 500)}...'
                  : extract;
              _wikiExtract = snippet;
            } else {
              _wikiError = 'No Wikipedia snippet found.';
            }
          } else {
            _wikiError = 'No Wikipedia page found for "$topic".';
          }
        } else {
          _wikiError = 'No Wikipedia result.';
        }
      } else {
        _wikiError = 'Wikipedia error.';
      }
    } catch (e) {
      if (!mounted) return;
      _wikiError = 'Wikipedia error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _wikiLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI Helper Methods
  // ---------------------------------------------------------------------------
  String _getMenuTitle(SelectionMenuType type) {
    switch (type) {
      case SelectionMenuType.askAi:
        return 'Ask AI';
      case SelectionMenuType.translate:
        return 'Translate';
      case SelectionMenuType.highlight:
        return 'Highlight';
      case SelectionMenuType.dictionary:
        return 'Dictionary';
      case SelectionMenuType.wikipedia:
        return 'Wikipedia';
      case SelectionMenuType.audio:
        return 'Audio';
      case SelectionMenuType.generateImage:
        return 'Images';
    }
  }

  IconData _getMenuIcon(SelectionMenuType type) {
    switch (type) {
      case SelectionMenuType.askAi:
        return Icons.chat_bubble_outline;
      case SelectionMenuType.translate:
        return Icons.translate;
      case SelectionMenuType.highlight:
        return Icons.highlight;
      case SelectionMenuType.dictionary:
        return Icons.book_outlined;
      case SelectionMenuType.wikipedia:
        return Icons.menu_book_outlined;
      case SelectionMenuType.audio:
        return Icons.volume_up_outlined;
      case SelectionMenuType.generateImage:
        return Icons.image_outlined;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Safely get the selected text or empty string if null
    final String selectionText = widget.selectedText ?? '';

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.deferToChild,
              child: Container(color: Colors.transparent),
            ),
          ),
          Align(
            alignment: widget.displayAtTop
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.only(
                top: widget.displayAtTop
                    ? MediaQuery.of(context).padding.top + 16
                    : 0,
                bottom: widget.displayAtTop
                    ? 0
                    : MediaQuery.of(context).padding.bottom + 16,
              ),
              height: _calculateMenuHeight(context),
              width: _calculateMenuWidth(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab-like navigation
                  Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _availableMenus.map((menuType) {
                        final isSelected = _availableMenus.indexOf(menuType) ==
                            _currentPageIndex;

                        // Determine if we should show text labels based on screen size and orientation
                        final size = MediaQuery.of(context).size;
                        final isLandscape = size.width > size.height;
                        final showText = !isLandscape ||
                            ResponsiveConstants.isTablet(context) ||
                            _availableMenus.length <= 4;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  _pageController.animateToPage(
                                    _availableMenus.indexOf(menuType),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutQuint,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .surface
                                            .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.7),
                                              blurRadius: 8,
                                              offset: const Offset(0, 5),
                                              spreadRadius: -2,
                                            )
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                              spreadRadius: -2,
                                            )
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getMenuIcon(menuType),
                                        size: 18,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                            : Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                      ),
                                      if (showText) const SizedBox(width: 4),
                                      if (showText)
                                        Text(
                                          _getMenuTitle(menuType),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                : Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 14,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // PageView with enhanced transition
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      children: _availableMenus.map(_buildMenuCard).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(SelectionMenuType menuType) {
    switch (menuType) {
      case SelectionMenuType.askAi:
        return _buildAskAiCard();
      case SelectionMenuType.translate:
        return _buildTranslateCard();
      case SelectionMenuType.highlight:
        return _buildHighlightsCard();
      case SelectionMenuType.dictionary:
        return _buildDictionaryCard();
      case SelectionMenuType.wikipedia:
        return _buildWikipediaCard();
      case SelectionMenuType.audio:
        return _buildAudioCard();
      case SelectionMenuType.generateImage:
        return _buildGenerateImagesCard();
    }
  }

  // ---------------------------------------------------------------------------
  // 1) ASK AI
  // ---------------------------------------------------------------------------
  Widget _buildAskAiCard() {
    final String selectionText = widget.selectedText ?? '';

    return _buildBaseCard(
      title: 'Ask AI',
      topRightWidget: Icon(
        Icons.chat_bubble_outline,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Get instant help from AI on your selected text.\n'
        'Ask questions, brainstorm ideas, or clarify context.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Ask now',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.askAi,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2) TRANSLATE
  // ---------------------------------------------------------------------------
  Widget _buildTranslateCard() {
    final String selectionText = widget.selectedText ?? '';

    return _buildBaseCard(
      title: 'Translate',
      topRightWidget: Icon(
        Icons.translate,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Translate "$selectionText" into another language.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'English (US)',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'Spanish',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'Vietnamese',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'More...',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3) HIGHLIGHTS
  // ---------------------------------------------------------------------------
  Widget _buildHighlightsCard() {
    final String selectionText = widget.selectedText ?? '';

    return _buildBaseCard(
      title: 'Highlights',
      topRightWidget: Icon(
        Icons.highlight,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Save "$selectionText" for future reference.\n'
        'Organize and revisit your highlights anytime.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Highlight',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.highlight,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'View all',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.highlight,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4) DICTIONARY
  // ---------------------------------------------------------------------------
  Widget _buildDictionaryCard() {
    final String selectionText = widget.selectedText ?? '';

    Widget dictionaryContent;
    if (_dictionaryLoading) {
      dictionaryContent = const Center(child: CircularProgressIndicator());
    } else if (_dictionaryError != null) {
      dictionaryContent = Text(
        _dictionaryError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else if (_dictionaryWord.isNotEmpty) {
      dictionaryContent = _buildDictionaryContent();
    } else {
      dictionaryContent = Text(
        'No dictionary result for "$selectionText".',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return _buildBaseCard(
      title: 'Dictionary',
      topRightWidget: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      body: dictionaryContent,
      bottomRow: [
        _buildTextButton(
          label: 'Open dictionary',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.dictionary,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'English (US)',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.dictionary,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'Vietnamese',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.dictionary,
            selectionText,
          ),
        ),
      ],
    );
  }

  Widget _buildDictionaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _dictionaryWord,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (_dictionaryPhonetic.isNotEmpty)
              Text(
                _dictionaryPhonetic,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _dictionaryDefinitions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${_dictionaryDefinitions[i]}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5) WIKIPEDIA
  // ---------------------------------------------------------------------------
  Widget _buildWikipediaCard() {
    final String selectionText = widget.selectedText ?? '';

    Widget wikiContent;
    if (_wikiLoading) {
      wikiContent = const Center(child: CircularProgressIndicator());
    } else if (_wikiError != null) {
      wikiContent = Text(
        _wikiError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else if (_wikiExtract.isNotEmpty) {
      wikiContent = Text(
        _wikiExtract,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else {
      wikiContent = Text(
        'No Wikipedia snippet found for "$selectionText".',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return _buildBaseCard(
      title: 'Wikipedia',
      topRightWidget: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          'W',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      body: wikiContent,
      bottomRow: [
        _buildTextButton(
          label: 'Open Wiki',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.wikipedia,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'Read more',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.wikipedia,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6) AUDIO
  // ---------------------------------------------------------------------------
  Widget _buildAudioCard() {
    final String selectionText = widget.selectedText ?? '';

    return _buildBaseCard(
      title: 'Audio',
      topRightWidget: Icon(
        Icons.volume_up_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Convert "$selectionText" to speech. Listen or download for offline use.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Play',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.audio,
            selectionText,
          ),
        ),
        _buildTextButton(
          label: 'Download',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.audio,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7) GENERATE IMAGES
  // ---------------------------------------------------------------------------
  Widget _buildGenerateImagesCard() {
    final String selectionText = widget.selectedText ?? '';

    return _buildBaseCard(
      title: 'Generate Images',
      topRightWidget: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Create AI-generated images from "$selectionText". '
        'Experiment with styles and variations.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Generate now',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.generateImage,
            selectionText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BASE CARD LAYOUT: Title row, tinted body box, bottom row
  // ---------------------------------------------------------------------------
  Widget _buildBaseCard({
    required String title,
    required Widget topRightWidget,
    required Widget body,
    required List<Widget> bottomRow,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Adjust padding based on device size
    final EdgeInsets contentPadding = _getCardPadding(context, isLandscape);

    final primaryColor =
        isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary;
    final cardColor = isDark
        ? const Color(0xFF352A3B) // Dark theme card color
        : Colors.white;
    final bodyColor = isDark
        ? const Color(0xFF251B2F).withOpacity(0.5)
        : theme.colorScheme.primary.withOpacity(0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.03),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: isDark
              ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: contentPadding,
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    topRightWidget,
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bodyColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : primaryColor.withOpacity(0.15),
                          width: 0.5,
                        ),
                      ),
                      child: body,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                ),
                const SizedBox(height: 16),
                Row(
                  children: bottomRow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT BUTTON (tinted text, stylish border)
  // ---------------------------------------------------------------------------
  Widget _buildTextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonColor =
        isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary;

    // Adjust font size based on device size
    final fontSize = ResponsiveConstants.isTablet(context) ? 13.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: buttonColor.withOpacity(0.8),
                width: 1.5,
              ),
              color: buttonColor.withOpacity(0.05),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: buttonColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESPONSIVE SIZING HELPER
  // ---------------------------------------------------------------------------
  double _calculateMenuHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Use the responsive constants from the app
    if (ResponsiveConstants.isLargeTablet(context)) {
      return isLandscape ? 300 : 330; // Smaller for large tablets
    } else if (ResponsiveConstants.isTablet(context)) {
      return isLandscape ? 320 : 350; // Slightly smaller for regular tablets
    } else {
      // For phones
      return isLandscape ? 330 : 385; // Original size for phones
    }
  }

  // Calculate appropriate padding based on device size
  EdgeInsets _getCardPadding(BuildContext context, bool isLandscape) {
    if (ResponsiveConstants.isLargeTablet(context)) {
      return isLandscape
          ? const EdgeInsets.all(16) // Large tablet in landscape
          : const EdgeInsets.all(18); // Large tablet in portrait
    } else if (ResponsiveConstants.isTablet(context)) {
      return isLandscape
          ? const EdgeInsets.all(18) // Tablet in landscape
          : const EdgeInsets.all(20); // Tablet in portrait
    } else {
      return isLandscape
          ? const EdgeInsets.all(16) // Phone in landscape
          : const EdgeInsets.all(20); // Phone in portrait (original)
    }
  }

  // Calculate appropriate width based on device size
  double _calculateMenuWidth(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    if (ResponsiveConstants.isLargeTablet(context)) {
      return isLandscape ? size.width * 0.6 : size.width * 0.75;
    } else if (ResponsiveConstants.isTablet(context)) {
      return isLandscape ? size.width * 0.65 : size.width * 0.85;
    } else {
      // For phones, use full width
      return double.infinity;
    }
  }
}
