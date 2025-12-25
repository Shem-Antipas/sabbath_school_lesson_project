import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quarterly.dart';
import '../services/api_service.dart';
import '../data/models/lesson.dart';
import '../data/models/lesson_content.dart';

final quarterlyListProvider = FutureProvider<List<Quarterly>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getQuarterlies('en');
});

final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  quarterlyId,
) async {
  final apiService = ref.watch(apiProvider);
  return apiService.fetchLessons(quarterlyId);
});

// Using autoDispose so the memory is cleaned when you leave the reader,
// but we will use 'keepAlive' during the session for fast day-switching.
final lessonContentProvider = FutureProvider.autoDispose
    .family<LessonContent, String>((ref, lessonIndex) async {
      final apiService = ref.watch(apiProvider);

      // This ensures that once a day is loaded, switching back to it is instant
      final link = ref.keepAlive();

      try {
        print("📡 Requesting content for: $lessonIndex");
        final content = await apiService.fetchLessonContent(lessonIndex);

        // Safety check: ensure the days list is actually present
        if (content.days == null || content.days!.isEmpty) {
          print("⚠️ Warning: Lesson content loaded but 'days' list is empty.");
        }

        return content;
      } catch (e, stack) {
        print("❌ Provider Error for $lessonIndex: $e");
        print(stack); // Helpful for debugging exact failure points

        // CONFLICT RESOLUTION:
        // This maps your proxy server errors to user-friendly messages
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
