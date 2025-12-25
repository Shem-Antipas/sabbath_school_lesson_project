import 'package:json_annotation/json_annotation.dart';

part 'lesson_content.g.dart';

@JsonSerializable()
class LessonContent {
  final String? id;
  final String? title;
  final String? date;
  final String? content;

  // This list will hold the 7 days (Day 01 - Day 07)
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
  final String? index; // This is the "01", "02"... "07" used for navigation

  LessonDay({this.id, this.title, this.date, this.index});

  factory LessonDay.fromJson(Map<String, dynamic> json) =>
      _$LessonDayFromJson(json);

  Map<String, dynamic> toJson() => _$LessonDayToJson(this);
}
