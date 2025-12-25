import 'package:json_annotation/json_annotation.dart';

part 'lesson_content.g.dart';

@JsonSerializable()
class LessonContent {
  final String? id;
  final String? title;
  final String? date;
  final String? content;

  // This is likely what was missing or causing the error in the .g file
  final List<LessonDay>? days;

  LessonContent({this.id, this.title, this.date, this.content, this.days});

  factory LessonContent.fromJson(Map<String, dynamic> json) =>
      _$LessonContentFromJson(json);

  Map<String, dynamic> toJson() => _$LessonContentToJson(this);
}

@JsonSerializable()
class LessonDay {
  final String? id;
  final String? title;
  final String? date;
  final String? index;

  LessonDay({this.id, this.title, this.date, this.index});

  factory LessonDay.fromJson(Map<String, dynamic> json) =>
      _$LessonDayFromJson(json);
}
