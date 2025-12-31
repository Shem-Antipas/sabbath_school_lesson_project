import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/quarterly.dart';
import '../models/lesson_content.dart' as reader;
import '../models/lesson.dart';

// --- API SERVICE ---
final apiProvider = Provider((ref) => ApiService());
// --- QUARTERLIES ---
final quarterlyListProvider = FutureProvider<List<Quarterly>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getQuarterlies('en');
});

// --- LESSON LIST ---
final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  quarterlyId,
) async {
  final api = ref.watch(apiProvider);
  return api.fetchLessons(quarterlyId);
});

// --- LESSON CONTENT (Merged & Optimized) ---
final lessonContentProvider = FutureProvider.autoDispose
    .family<reader.LessonContent, String>((ref, lessonIndex) async {
      // Use the global apiProvider we just defined
      final apiService = ref.watch(apiProvider);
      // Keep the provider alive for instant switching
      ref.keepAlive();
      try {
        print("📡 Requesting content for: $lessonIndex");

        // Explicitly type the result using the reader prefix
        final reader.LessonContent content = await apiService
            .fetchLessonContent(lessonIndex);

        if (content.days?.isEmpty ?? true) {
          print(
            "⚠️ Warning: Lesson content loaded but 'days' list is null or empty.",
          );
        }

        return content;
      } catch (e, stack) {
        print("❌ Provider Error for $lessonIndex: $e");
        print(stack);
        if (e.toString().contains("empty") ||
            e.toString().contains("404") ||
            e.toString().contains("500")) {
          throw Exception(
            "The study material for this date ($lessonIndex) is not yet available on the server.",
          );
        }
        throw Exception(
          "Failed to load daily study. Please check your connection.",
        );
      }
    });
