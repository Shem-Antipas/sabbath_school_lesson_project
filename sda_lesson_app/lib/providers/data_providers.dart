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
  // It's safer to ensure the quarterlyId is clean here or in the service
  return apiService.fetchLessons(quarterlyId);
});

final lessonContentProvider = FutureProvider.family<LessonContent, String>((
  ref,
  lessonIndex,
) async {
  final apiService = ref.watch(apiProvider);

  try {
    print("📡 Requesting content for: $lessonIndex");
    final content = await apiService.fetchLessonContent(lessonIndex);
    return content;
  } catch (e, stack) {
    print("❌ Provider Error for $lessonIndex: $e");

    // CONFLICT RESOLUTION:
    // If the error is a 404 or a 500 from your proxy, or the 'empty data'
    // exception from your ApiService, we show the "Not Available" message.
    if (e.toString().contains("empty") ||
        e.toString().contains("404") ||
        e.toString().contains("500")) {
      throw Exception(
        "The study material for this date is not yet available on the server.",
      );
    }

    throw Exception(
      "Failed to load daily study. Please check your connection.",
    );
  }
});
