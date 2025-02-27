class SearchConstants {
  static const Map<String, String> typeValues = {
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

  static const Map<String, String> sortValues = {
    'Most Relevant': '',
    'Newest': 'newest',
    'Oldest': 'oldest',
    'Largest': 'largest',
    'Smallest': 'smallest',
  };

  static const List<String> fileTypes = ["All", "PDF", "Epub", "Cbr", "Cbz"];

  static const List<String> topSearchQueries = [
    "The 48 Laws of Power",
    "Atomic Habits",
    "Control Your Mind and Master Your Feelings"
  ];

  static const List<String> trendingQueries = [
    "fiction",
    "novel",
    "non-fiction",
    "romance"
  ];
}
