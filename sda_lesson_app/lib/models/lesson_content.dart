// lib/models/lesson_content.dart
import '../models/lesson.dart';

class LessonContent {
  final Lesson? lesson;
  final List<Day>? days;
  final String? id;
  final String? title;
  final String? subtitle;
  final String? date;
  final String? content;
  final String? index;
  final String? cover;
  final String? pdf;
  final List<LessonSection>? children;

  LessonContent({
    this.lesson, this.days, this.id, this.title, this.subtitle, this.date,
    this.content, this.index, this.cover, this.pdf, this.children,
  });

  Map<String, dynamic> toJson() => {};

  factory LessonContent.fromJson(Map<String, dynamic> json) {
    try {
      // 1. PDF
      String? foundPdf;
      bool isValidLink(String? link) => link != null && link.isNotEmpty && (link.toLowerCase().startsWith('http') || link.toLowerCase().endsWith('.pdf'));
      if (isValidLink(json['pdf'])) foundPdf = json['pdf'];
      else if (isValidLink(json['src'])) foundPdf = json['src'];
      else if (isValidLink(json['target'])) foundPdf = json['target'];
      else if (json['pdfs'] != null && (json['pdfs'] as List).isNotEmpty) {
        if (isValidLink(json['pdfs'][0]['target'])) foundPdf = json['pdfs'][0]['target'];
      }

      // 2. TEXT (Recursive)
      String? findContent(dynamic data) {
        if (data is Map) {
          if (data['content']?.toString().isNotEmpty ?? false) return data['content'];
          if (data['markdown']?.toString().isNotEmpty ?? false) return data['markdown'];
          if (data['description']?.toString().isNotEmpty ?? false) return data['description'];
          if (data['lesson'] != null) return findContent(data['lesson']);
        }
        return null;
      }
      String? foundContent = findContent(json);

      // 3. CHAPTERS / SECTIONS (The fix for Books)
      List<LessonSection> foundChildren = [];
      if (json['children'] != null && json['children'] is List) {
        foundChildren.addAll((json['children'] as List).map((x) => LessonSection.fromJson(x)));
      }
      // ✅ Resource API uses 'sections', map these to children!
      if (json['sections'] != null && json['sections'] is List) {
        for (var s in json['sections']) {
           foundChildren.add(LessonSection.fromJson(s)); // Add section itself
           // Add any nested children
           if (s['children'] != null && s['children'] is List) {
             foundChildren.addAll((s['children'] as List).map((x) => LessonSection.fromJson(x)));
           }
        }
      }

      return LessonContent(
        lesson: json['lesson'] != null ? Lesson.fromJson(json['lesson']) : null,
        days: (json['days'] as List?)?.map((e) => Day.fromJson(e)).toList(),
        id: json['id']?.toString(),
        title: json['title'] ?? json['lesson']?['title'],
        subtitle: json['subtitle'] ?? json['lesson']?['subtitle'],
        date: json['date'],
        content: foundContent,
        index: json['index'],
        cover: json['cover'] ?? json['lesson']?['cover'],
        pdf: foundPdf,
        children: foundChildren.isNotEmpty ? foundChildren : null,
      );
    } catch (e) {
      print("❌ JSON PARSING ERROR: $e");
      rethrow;
    }
  }
}

class LessonSection {
  final String id;
  final String title;
  final String? subtitle;
  LessonSection({required this.id, required this.title, this.subtitle});
  factory LessonSection.fromJson(Map<String, dynamic> json) {
    return LessonSection(
      id: json['id'] ?? json['index'] ?? '', 
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
    );
  }
}
// Keep Day/BibleVerse classes...
class Day {
  final String id; final String index; final String title; final String date; final String content; final List<BibleVerse>? bible;
  Day({required this.id, required this.index, required this.title, required this.date, required this.content, required this.bible});
  factory Day.fromJson(Map<String, dynamic> json) => Day(id: json['id']?.toString()??'', index: json['index']?.toString()??'', title: json['title']??'', date: json['date']??'', content: json['content']??'', bible: (json['bible'] as List?)?.map((v)=>BibleVerse.fromJson(v)).toList());
  Map<String, dynamic> toJson() => {};
}
class BibleVerse {
  final String name; final String content;
  BibleVerse({required this.name, required this.content});
  factory BibleVerse.fromJson(Map<String, dynamic> json) => BibleVerse(name: json['name']??'', content: json['content']??'');
  Map<String, dynamic> toJson() => {'name': name, 'content': content};
}