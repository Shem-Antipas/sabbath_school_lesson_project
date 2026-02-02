import 'package:flutter/foundation.dart'; // ✅ Required for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- API SERVICE IMPORTS ---
import '../services/api_service.dart';
import '../models/quarterly.dart';
import '../models/lesson_content.dart' as reader;
import '../models/lesson.dart';

// --- API SERVICE ---
final apiProvider = Provider((ref) => ApiService());

// ============================================================================
// ✅ MAIN QUARTERLIES LIST (Adult, Youth, Children)
// ============================================================================
// This provider fetches ALL quarterlies. The filtering (Standard vs Alive in Jesus)
// is now handled by the UI screens (HomeScreen vs AliveInJesusScreen).
final quarterlyListProvider = FutureProvider<List<Quarterly>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getQuarterlies('en');
});

// --- LESSON LIST (Standard - Adult/Cornerstone) ---
final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  quarterlyId,
) async {
  final api = ref.watch(apiProvider);
  return api.fetchLessons(quarterlyId);
});

// ✅ ALIAS: So DashboardScreen can find 'lessonListProvider'
final lessonListProvider = lessonsProvider;

// --- LESSON CONTENT (Reader) ---
final lessonContentProvider = FutureProvider.autoDispose
    .family<reader.LessonContent, String>((ref, lessonIndex) async {
      final apiService = ref.watch(apiProvider);
      ref.keepAlive(); // Keep content in memory while reading
      
      try {
        debugPrint("📡 Requesting content for: $lessonIndex");

        final reader.LessonContent content = await apiService
            .fetchLessonContent(lessonIndex);

        if (content.days?.isEmpty ?? true) {
          debugPrint("⚠️ Warning: Lesson content loaded but 'days' list is null or empty.");
        }

        return content;
      } catch (e, stack) {
        debugPrint("❌ Provider Error for $lessonIndex: $e");
        debugPrint(stack.toString());
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

final navIndexProvider = StateProvider<int>((ref) => 0);

// ============================================================================
// ✅ ALIVE IN JESUS: DETAILS PROVIDER (Delegates to ApiService)
// ============================================================================
// We keep this because the Detail Screen for Alive in Jesus needs the raw JSON map
// (handled by 'fetchQuarterlyDetailsWithFallback' in ApiService) rather than the
// strict 'Quarterly' model used by standard screens.
final aliveInJesusDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final api = ref.watch(apiProvider);
  
  // This uses the new method we added to ApiService which handles:
  // 1. V2 vs V1 fallback
  // 2. Checking if it's a PDF (HTML response)
  return api.fetchQuarterlyDetailsWithFallback(id);
});