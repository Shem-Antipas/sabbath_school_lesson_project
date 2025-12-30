import 'package:sda_lesson_app/models/lesson.dart';

class LessonContent {
  final Lesson? lesson;
  final List<Day>? days;
  final String? id;
  final String? title;
  final String? date;
  final String? content;
  final String? index;

  LessonContent({
    this.lesson,
    this.days,
    this.id,
    this.title,
    this.date,
    this.content,
    this.index,
  });

  // ADD THIS: Converts LessonContent to a Map for saving
  Map<String, dynamic> toJson() {
    return {
      'lesson': lesson?.toJson(), // Note: Your Lesson model also needs toJson()
      'days': days?.map((e) => e.toJson()).toList(),
      'id': id,
      'title': title,
      'date': date,
      'content': content,
      'index': index,
    };
  }

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    try {
      return LessonContent(
        lesson: json['lesson'] != null
            ? Lesson.fromJson(json['lesson'] as Map<String, dynamic>)
            : null,
        days: (json['days'] as List<dynamic>?)?.map((e) {
          return Day.fromJson(e as Map<String, dynamic>);
        }).toList(),
        id: json['id']?.toString(),
        title: json['title'] as String?,
        date: json['date'] as String?,
        content: json['content'] as String?,
        index: json['index'] as String?,
      );
    } catch (e) {
      print("❌ JSON PARSING ERROR: $e");
      rethrow;
    }
  }
}

class Day {
  final String id;
  final String index;
  final String title;
  final String date;
  final String content;
  final List<BibleVerse>? bible;

  Day({
    required this.id,
    required this.index,
    required this.title,
    required this.date,
    required this.content,
    required this.bible,
  });

  // ADD THIS: Converts Day to a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'title': title,
      'date': date,
      'content': content,
      'bible': bible?.map((v) => v.toJson()).toList(),
    };
  }

  factory Day.fromJson(Map<String, dynamic> json) {
    return Day(
      id: json['id']?.toString() ?? '',
      index: json['index']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      content: json['content'] as String? ?? '',
      bible: (json['bible'] as List?)
          ?.map((v) => BibleVerse.fromJson(v))
          .toList(),
    );
  }
}

class BibleVerse {
  final String name;
  final String content;

  BibleVerse({required this.name, required this.content});

  // ADD THIS: Converts BibleVerse to a Map
  Map<String, dynamic> toJson() {
    return {'name': name, 'content': content};
  }

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(name: json['name'] ?? '', content: json['content'] ?? '');
  }
}
