import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import '../utils/bible_sort_helper.dart'; // ✅ Import the helper

final bibleApiServiceProvider = Provider((ref) => BibleApiService());

final bibleVersionProvider = StateProvider<BibleVersion>((ref) => BibleVersion.kjv);

// Fetches the list of books automatically
final bibleBooksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(bibleApiServiceProvider);
  return service.fetchBooks(); // Ensure fetchBooks uses the current version if needed
});

// ✅ NEW: Search Provider with Chronological Sorting
// Usage in UI: ref.watch(bibleSearchProvider("grace"))
final bibleSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final service = ref.read(bibleApiServiceProvider);
  final currentVersion = ref.read(bibleVersionProvider);

  // 1. Fetch Raw Results from API/Database
  // (Assumes your service has a searchVerses method)
  final rawResults = await service.searchVerses(query, version: currentVersion);

  // 2. Sort them Chronologically (Gen -> Rev)
  return BibleSortHelper.sortResults(rawResults);
});