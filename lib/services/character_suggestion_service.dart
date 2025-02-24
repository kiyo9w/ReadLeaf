import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CharacterSuggestionService {
  static Map<String, dynamic>? _personalityData;
  static final Map<String, List<String>> _cachedRelatedTraits = {};

  static Future<void> initialize() async {
    final jsonString =
        await rootBundle.loadString('lib/data/personality_traits.json');
    _personalityData = json.decode(jsonString);
  }

  static List<String> getSuggestionsForField(String field) {
    if (_personalityData == null) {
      return [];
    }

    switch (field) {
      case 'tags':
        return ([
          ...(_personalityData!['positive_traits'] as List<dynamic>)
              .cast<String>(),
          ...(_personalityData!['neutral_traits'] as List<dynamic>)
              .cast<String>(),
        ]).toSet().toList();
      default:
        return [];
    }
  }

  static List<String> getRelatedTraits(String trait, {int maxSuggestions = 3}) {
    if (_cachedRelatedTraits.containsKey(trait)) {
      return _cachedRelatedTraits[trait]!;
    }

    if (_personalityData == null) {
      return [];
    }

    final relationships =
        _personalityData!['trait_relationships'] as Map<String, dynamic>;
    if (relationships.containsKey(trait)) {
      final traitRelations = relationships[trait] as Map<String, dynamic>;
      final sortedTraits = traitRelations.entries.toList()
        ..sort((a, b) => (b.value as double).compareTo(a.value as double));

      final relatedTraits =
          sortedTraits.take(maxSuggestions).map((e) => e.key).toList();

      _cachedRelatedTraits[trait] = relatedTraits;
      return relatedTraits;
    }

    // If no direct relationships found, try finding traits from the same category
    final categories =
        _personalityData!['trait_categories'] as Map<String, dynamic>;
    for (final category in categories.entries) {
      final traits = category.value as List<dynamic>;
      if (traits.contains(trait)) {
        final otherTraits = traits
            .where((t) => t != trait)
            .take(maxSuggestions)
            .cast<String>()
            .toList();
        _cachedRelatedTraits[trait] = otherTraits;
        return otherTraits;
      }
    }

    return [];
  }

  static List<String> getTaglineSuggestions(List<String> selectedTraits) {
    if (selectedTraits.isEmpty) return [];

    final suggestions = <String>[];
    for (final trait in selectedTraits) {
      final relatedTraits = getRelatedTraits(trait);
      for (final related in relatedTraits) {
        suggestions.add('The $trait and $related One');
        suggestions.add('A $trait Individual with $related Qualities');
      }
    }
    return suggestions.take(5).toList();
  }

  static List<String> getGreetingSuggestions(
    List<String> selectedTraits,
    String? context,
  ) {
    if (selectedTraits.isEmpty) return [];

    final suggestions = <String>[];
    for (final trait in selectedTraits) {
      final relatedTraits = getRelatedTraits(trait);
      suggestions
          .add('Greetings! As a $trait person, I\'m excited to meet you.');
      for (final related in relatedTraits) {
        suggestions.add(
          'Hello! I bring my $trait nature and $related approach to every conversation.',
        );
      }
    }
    return suggestions.take(5).toList();
  }

  static List<String> getScenarioSuggestions(
    List<String> selectedTraits,
    String? context,
  ) {
    if (selectedTraits.isEmpty) return [];

    final suggestions = <String>[];
    for (final trait in selectedTraits) {
      final relatedTraits = getRelatedTraits(trait);
      suggestions.add(
        'In a world where $trait qualities are valued, I thrive by being authentically myself.',
      );
      for (final related in relatedTraits) {
        suggestions.add(
          'My $trait personality combined with my $related nature creates unique perspectives.',
        );
      }
    }
    return suggestions.take(5).toList();
  }

  static Map<String, String> getContextualGreetings(
    List<String> selectedTraits,
    String context,
  ) {
    final greetings = <String, String>{};
    if (selectedTraits.isEmpty) return greetings;

    for (final trait in selectedTraits) {
      greetings[trait] =
          'As a $trait individual, I\'m looking forward to our conversation!';
    }
    return greetings;
  }

  static Map<String, String> getContextualScenarios(
    List<String> selectedTraits,
    String context,
  ) {
    final scenarios = <String, String>{};
    if (selectedTraits.isEmpty) return scenarios;

    for (final trait in selectedTraits) {
      final relatedTraits = getRelatedTraits(trait);
      if (relatedTraits.isNotEmpty) {
        scenarios[trait] =
            'Drawing from my $trait nature and ${relatedTraits.first} tendencies, I create meaningful connections.';
      }
    }
    return scenarios;
  }

  static List<String> getFilteredSuggestions(
    String field,
    List<String> selectedTraits,
  ) {
    final allSuggestions = getSuggestionsForField(field);
    return allSuggestions
        .where((suggestion) => !selectedTraits.contains(suggestion))
        .toList();
  }
}
