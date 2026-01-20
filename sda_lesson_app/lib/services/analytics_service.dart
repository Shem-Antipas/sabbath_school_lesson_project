import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  // Singleton pattern (optional, but good for services)
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // 1. Log Hymn Selection
  Future<void> logSelectHymn({required int hymnId, required String hymnTitle}) async {
    await _analytics.logEvent(
      name: 'select_hymn', // Event Name (Keep it snake_case)
      parameters: {
        'hymn_number': hymnId,
        'hymn_title': hymnTitle,
      },
    );
  }

  // 2. Log Bible Chapter Read
  Future<void> logReadBible({required String book, required int chapter}) async {
    await _analytics.logEvent(
      name: 'read_bible',
      parameters: {
        'bible_book': book,
        'chapter_number': chapter,
        'full_reference': '$book $chapter',
      },
    );
  }

  // 3. Log EGW Book Read
  Future<void> logReadEgw({required String bookTitle, required String chapterTitle}) async {
    await _analytics.logEvent(
      name: 'read_egw',
      parameters: {
        'egw_book': bookTitle,
        'egw_chapter': chapterTitle,
      },
    );
  }

  // 4. Log Lesson Read
  Future<void> logReadLesson({required String lessonTitle, required String date}) async {
    await _analytics.logEvent(
      name: 'read_lesson',
      parameters: {
        'lesson_title': lessonTitle,
        'date': date,
      },
    );
  }
}