import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents a highlight in the EPUB
class EpubHighlight {
  final String id;
  final String text;
  final int chapterIndex;
  final int pageNumberInChapter;
  final Color color;
  final DateTime createdAt;
  final String? note;

  EpubHighlight({
    String? id,
    required this.text,
    required this.chapterIndex,
    required this.pageNumberInChapter,
    this.color = Colors.yellow,
    DateTime? createdAt,
    this.note,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'chapterIndex': chapterIndex,
      'pageNumberInChapter': pageNumberInChapter,
      'color': color.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory EpubHighlight.fromMap(Map<String, dynamic> map) {
    return EpubHighlight(
      id: map['id'],
      text: map['text'],
      chapterIndex: map['chapterIndex'],
      pageNumberInChapter: map['pageNumberInChapter'],
      color: Color(map['color']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      note: map['note'],
    );
  }

  EpubHighlight copyWith({
    String? id,
    String? text,
    int? chapterIndex,
    int? pageNumberInChapter,
    Color? color,
    DateTime? createdAt,
    String? note,
  }) {
    return EpubHighlight(
      id: id ?? this.id,
      text: text ?? this.text,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      pageNumberInChapter: pageNumberInChapter ?? this.pageNumberInChapter,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }
}

/// Manages text highlights in the EPUB reader
class EpubHighlightManager extends ChangeNotifier {
  // Highlights by chapter index
  final Map<int, List<EpubHighlight>> _highlights = {};

  // Currently selected/active highlight
  EpubHighlight? _activeHighlight;

  // Animation for highlighting
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  Timer? _pulseTimer;

  // Constructor with animation controller
  EpubHighlightManager({AnimationController? pulseController}) {
    if (pulseController != null) {
      _setupPulseAnimation(pulseController);
    }
  }

  /// Sets up the pulse animation for highlights
  void _setupPulseAnimation(AnimationController controller) {
    _pulseController = controller;
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (_pulseTimer?.isActive == true) {
          controller.forward();
        }
      }
    });
  }

  /// Gets the highlights for a specific chapter
  List<EpubHighlight> getHighlightsForChapter(int chapterIndex) {
    return _highlights[chapterIndex] ?? [];
  }

  /// Gets all highlights
  List<EpubHighlight> getAllHighlights() {
    List<EpubHighlight> allHighlights = [];
    for (var list in _highlights.values) {
      allHighlights.addAll(list);
    }
    return allHighlights;
  }

  /// Adds a new highlight
  void addHighlight(EpubHighlight highlight) {
    if (!_highlights.containsKey(highlight.chapterIndex)) {
      _highlights[highlight.chapterIndex] = [];
    }

    _highlights[highlight.chapterIndex]!.add(highlight);
    _activeHighlight = highlight;
    notifyListeners();

    // Start pulse animation
    _startPulseAnimation();
  }

  /// Updates an existing highlight
  void updateHighlight(EpubHighlight highlight) {
    final chapterHighlights = _highlights[highlight.chapterIndex];
    if (chapterHighlights == null) return;

    final index = chapterHighlights.indexWhere((h) => h.id == highlight.id);
    if (index < 0) return;

    chapterHighlights[index] = highlight;
    _activeHighlight = highlight;
    notifyListeners();
  }

  /// Removes a highlight
  void removeHighlight(String highlightId) {
    for (final chapterIndex in _highlights.keys) {
      final highlights = _highlights[chapterIndex]!;
      final index = highlights.indexWhere((h) => h.id == highlightId);

      if (index >= 0) {
        highlights.removeAt(index);

        if (_activeHighlight?.id == highlightId) {
          _activeHighlight = null;
        }

        notifyListeners();
        return;
      }
    }
  }

  /// Sets the active highlight (the one that's currently selected)
  void setActiveHighlight(EpubHighlight? highlight) {
    _activeHighlight = highlight;
    notifyListeners();

    if (highlight != null) {
      _startPulseAnimation();
    } else {
      _stopPulseAnimation();
    }
  }

  /// Gets the currently active highlight
  EpubHighlight? get activeHighlight => _activeHighlight;

  /// Gets the pulse animation
  Animation<double>? get pulseAnimation => _pulseAnimation;

  /// Starts the pulse animation for the highlight
  void _startPulseAnimation() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 3000), () {
      _stopPulseAnimation();
    });

    if (_pulseController != null && !_pulseController!.isAnimating) {
      _pulseController!.forward();
    }
  }

  /// Stops the pulse animation
  void _stopPulseAnimation() {
    _pulseTimer?.cancel();
    _pulseTimer = null;

    if (_pulseController != null && _pulseController!.isAnimating) {
      _pulseController!.stop();
      _pulseController!.reset();
    }
  }

  /// Loads highlights from a list of maps
  void loadFromList(List<Map<String, dynamic>> highlightMaps) {
    _highlights.clear();

    for (final map in highlightMaps) {
      final highlight = EpubHighlight.fromMap(map);

      if (!_highlights.containsKey(highlight.chapterIndex)) {
        _highlights[highlight.chapterIndex] = [];
      }

      _highlights[highlight.chapterIndex]!.add(highlight);
    }

    notifyListeners();
  }

  /// Exports highlights to a list of maps for serialization
  List<Map<String, dynamic>> exportToList() {
    final allHighlights = getAllHighlights();
    return allHighlights.map((h) => h.toMap()).toList();
  }

  /// Disposes resources
  @override
  void dispose() {
    _pulseTimer?.cancel();
    // Don't dispose _pulseController as it might be owned by another widget
    super.dispose();
  }
}
