class Lesson {
  final String id;
  final String title;
  final String? subtitle;
  final String? cover; // This is the field used for the header image
  final String? index;
  final String? path;

  Lesson({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    this.index,
    this.path,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String? ?? '',
      // Ensures the title is never null to prevent UI errors
      title: json['title'] as String? ?? 'Untitled Lesson',
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
      'subtitle': subtitle,
      'cover': cover,
      'index': index,
      'path': path,
    };
  }
}
