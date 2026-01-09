class BookMeta {
  final String id;
  final String title;
  final String author;
  final String coverImage;
  final String filePath;

  BookMeta({
    required this.id,
    required this.title,
    required this.author,
    required this.coverImage,
    required this.filePath,
  });

  factory BookMeta.fromJson(Map<String, dynamic> json) {
    return BookMeta(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      coverImage: json['cover_image'],
      filePath: json['file_path'],
    );
  }
}