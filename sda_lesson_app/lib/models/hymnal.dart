class Hymn {
  final int id;
  final String title;
  final String lyrics;

  Hymn({required this.id, required this.title, required this.lyrics});

  factory Hymn.fromJson(Map<String, dynamic> json) =>
      Hymn(id: json['id'], title: json['title'], lyrics: json['lyrics']);
}
