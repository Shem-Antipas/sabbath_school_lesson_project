class Lesson {
  final String id;
  final String title;
  final String startDate; // ✅ camelCase
  final String endDate;   // ✅ camelCase
  final String? subtitle;
  final String? cover;
  final String? index;
  final String? path;

  Lesson({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.subtitle,
    this.cover,
    this.index,
    this.path,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Lesson',
      // Map JSON 'start_date' -> Dart 'startDate'
      startDate: json['start_date'] as String? ?? '', 
      endDate: json['end_date'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      cover: json['cover'] as String?,
      index: json['index'] as String?,
      path: json['path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start_date': startDate,
      'end_date': endDate,
      'subtitle': subtitle,
      'cover': cover,
      'index': index,
      'path': path,
    };
  }
}