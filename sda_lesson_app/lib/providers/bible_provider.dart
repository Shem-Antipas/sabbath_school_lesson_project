import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';

final bibleApiServiceProvider = Provider((ref) => BibleApiService());

// This provider fetches the list of books automatically
final bibleBooksProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final service = ref.watch(bibleApiServiceProvider);
  return service.fetchBooks();
});
