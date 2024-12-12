import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// final fileListProvider = Provider<List<String>>((ref) {
//   final prefs = ref.watch(sharedPreferencesProvider);
//   final filePaths = prefs.getStringList('filePaths') ?? [];
//   return filePaths;
// });