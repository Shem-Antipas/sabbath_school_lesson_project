// lib/models/lesson_content.dart
import '../models/lesson.dart';

class LessonContent {
  final Lesson? lesson;
  final List<Day>? days;
  final String? id;
  final String? title;
  final String? date;
  final String? content;
  final String? index;
  final String? cover;
  final String? pdf;

  LessonContent({
    this.lesson,
    this.days,
    this.id,
    this.title,
    this.date,
    this.content,
    this.index,
    this.cover,
    this.pdf,
  });

  Map<String, dynamic> toJson() {
    return {
      'lesson': lesson?.toJson(),
      'days': days?.map((e) => e.toJson()).toList(),
      'id': id,
      'title': title,
      'date': date,
      'content': content,
      'index': index,
      'cover': cover,
      'pdf': pdf,
    };
  }

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    try {
      // --- 1. PDF HUNTING ---
      String? foundPdf;
      bool isValidLink(String? link) {
        if (link == null || link.isEmpty) return false;
        final lower = link.toLowerCase();
        return lower.startsWith('http') || lower.endsWith('.pdf');
      }

      if (isValidLink(json['pdf'])) foundPdf = json['pdf'];
      else if (isValidLink(json['src'])) foundPdf = json['src'];
      else if (isValidLink(json['target'])) foundPdf = json['target'];
      else if (json['pdfs'] != null && (json['pdfs'] as List).isNotEmpty) {
        final firstPdf = json['pdfs'][0]['target'];
        if (isValidLink(firstPdf)) foundPdf = firstPdf;
      } else if (json['data'] != null && isValidLink(json['data']['pdf'])) {
        foundPdf = json['data']['pdf'];
      }

      // --- 2. TEXT CONTENT HUNTING (Improved) ---
      String? foundContent;
      
      // List of possible fields where text might hide
      final possibleFields = [
        json['content'],
        json['markdown'], // ✅ Often used in Resources
        json['subtitle'],
        json['description'],
        json['story'], // Sometimes used for stories
        json['lesson']?['content'],
        json['lesson']?['markdown'],
        json['lesson']?['description']
      ];

      // Grab the first non-empty text found
      for (var field in possibleFields) {
        if (field != null && field is String && field.isNotEmpty) {
          foundContent = field;
          break;
        } else if (field is List) {
          // Sometimes 'story' is a list of strings
          foundContent = field.join("\n\n");
          break;
        }
      }

      // --- 3. TITLE HUNTING ---
      String? foundTitle = json['title'] ?? json['lesson']?['title'];

      return LessonContent(
        lesson: json['lesson'] != null
            ? Lesson.fromJson(json['lesson'] as Map<String, dynamic>)
            : null,
        days: (json['days'] as List<dynamic>?)?.map((e) {
          return Day.fromJson(e as Map<String, dynamic>);
        }).toList(),
        id: json['id']?.toString(),
        title: foundTitle,
        date: json['date'] as String?,
        content: foundContent, // ✅ Now checks markdown/subtitle too
        index: json['index'] as String?,
        cover: json['cover'] as String? ?? json['lesson']?['cover'],
        pdf: foundPdf,
      );
    } catch (e) {
      print("❌ JSON PARSING ERROR: $e");
      rethrow;
    }
  }
}

// (Keep Day and BibleVerse classes the same)
class Day {
  final String id;
  final String index;
  final String title;
  final String date;
  final String content;
  final List<BibleVerse>? bible;

  Day({required this.id, required this.index, required this.title, required this.date, required this.content, required this.bible});
  Map<String, dynamic> toJson() => {'id': id, 'index': index, 'title': title, 'date': date, 'content': content, 'bible': bible?.map((v) => v.toJson()).toList()};
  factory Day.fromJson(Map<String, dynamic> json) => Day(id: json['id']?.toString() ?? '', index: json['index']?.toString() ?? '', title: json['title'] ?? '', date: json['date'] ?? '', content: json['content'] ?? '', bible: (json['bible'] as List?)?.map((v) => BibleVerse.fromJson(v)).toList());
}

class BibleVerse {
  final String name;
  final String content;
  BibleVerse({required this.name, required this.content});
  Map<String, dynamic> toJson() => {'name': name, 'content': content};
  factory BibleVerse.fromJson(Map<String, dynamic> json) => BibleVerse(name: json['name'] ?? '', content: json['content'] ?? '');
}