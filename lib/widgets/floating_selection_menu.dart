import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final String selectedText;
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

  @override
  void initState() {
    super.initState();
    final int wordCount =
        widget.selectedText.trim().split(RegExp(r'\s+')).length;

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
        setState(() {
          _currentPageIndex = page;
        });
      }
    });

    if (_availableMenus.contains(SelectionMenuType.dictionary)) {
      _fetchDictionaryData(widget.selectedText);
    }

    if (_availableMenus.contains(SelectionMenuType.wikipedia)) {
      _fetchWikipediaData(widget.selectedText);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DICTIONARY API (dictionaryapi.dev, English only)
  // ---------------------------------------------------------------------------
  Future<void> _fetchDictionaryData(String word) async {
    setState(() {
      _dictionaryLoading = true;
      _dictionaryError = null;
      _dictionaryWord = '';
      _dictionaryPhonetic = '';
      _dictionaryDefinitions = [];
    });

    try {
      final url = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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
      _dictionaryError = 'Dictionary error: $e';
    } finally {
      setState(() {
        _dictionaryLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // WIKIPEDIA API (English by default)
  // ---------------------------------------------------------------------------
  Future<void> _fetchWikipediaData(String topic) async {
    setState(() {
      _wikiLoading = true;
      _wikiError = null;
      _wikiExtract = '';
    });

    try {
      final url = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query'
        '&prop=extracts&explaintext&format=json&redirects=1&titles=$topic',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
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
      _wikiError = 'Wikipedia error: $e';
    } finally {
      setState(() {
        _wikiLoading = false;
      });
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
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
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
              height: 385,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab-like navigation
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableMenus.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final isSelected = index == _currentPageIndex;
                        final menuType = _availableMenus[index];
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getMenuIcon(menuType),
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getMenuTitle(menuType),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
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
            widget.selectedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2) TRANSLATE
  // ---------------------------------------------------------------------------
  Widget _buildTranslateCard() {
    return _buildBaseCard(
      title: 'Translate',
      topRightWidget: Icon(
        Icons.translate,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Translate "${widget.selectedText}" into another language.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'English (US)',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'Spanish',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'More...',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            widget.selectedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3) HIGHLIGHTS
  // ---------------------------------------------------------------------------
  Widget _buildHighlightsCard() {
    return _buildBaseCard(
      title: 'Highlights',
      topRightWidget: Icon(
        Icons.highlight,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Save "${widget.selectedText}" for future reference.\n'
        'Organize and revisit your highlights anytime.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Highlight',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.highlight,
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'View all',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.highlight,
            widget.selectedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4) DICTIONARY
  // ---------------------------------------------------------------------------
  Widget _buildDictionaryCard() {
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
        'No dictionary result for "${widget.selectedText}".',
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
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'English (US)',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.translate,
            widget.selectedText,
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
        'No Wikipedia snippet found for "${widget.selectedText}".',
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
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'Read more',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.wikipedia,
            widget.selectedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6) AUDIO
  // ---------------------------------------------------------------------------
  Widget _buildAudioCard() {
    return _buildBaseCard(
      title: 'Audio',
      topRightWidget: Icon(
        Icons.volume_up_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Convert "${widget.selectedText}" to speech. Listen or download for offline use.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Play',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.audio,
            widget.selectedText,
          ),
        ),
        _buildTextButton(
          label: 'Download',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.audio,
            widget.selectedText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7) GENERATE IMAGES
  // ---------------------------------------------------------------------------
  Widget _buildGenerateImagesCard() {
    return _buildBaseCard(
      title: 'Generate Images',
      topRightWidget: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.secondary,
      ),
      body: Text(
        'Create AI-generated images from "${widget.selectedText}". '
        'Experiment with styles and variations.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      bottomRow: [
        _buildTextButton(
          label: 'Generate now',
          onTap: () => widget.onMenuSelected(
            SelectionMenuType.generateImage,
            widget.selectedText,
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

    return Center(
      child: Card(
        color: isDark
            ? const Color(0xFF352A3B) // Dark theme card color
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE0E0E0),
            width: 0.5,
          ),
        ),
        elevation: 8,
        shadowColor: Colors.black38,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                      color: isDark
                          ? const Color(0xFFAA96B6)
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  topRightWidget,
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color:
                    isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE0E0E0),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF251B2F).withValues(alpha: 0.5)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF4A4A4A)
                            : theme.colorScheme.primary.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: body,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color:
                    isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE0E0E0),
              ),
              const SizedBox(height: 12),
              Row(
                children: bottomRow,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT BUTTON (tinted text, no background)
  // ---------------------------------------------------------------------------
  Widget _buildTextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color:
                  isDark ? const Color(0xFFAA96B6) : theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
