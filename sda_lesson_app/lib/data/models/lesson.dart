import 'package:json_annotation/json_annotation.dart';

part 'lesson.g.dart';

@JsonSerializable()
class Lesson {
  final String? id;
  final String? title;

  @JsonKey(name: 'start_date')
  final String? startDate;

  @JsonKey(name: 'end_date')
  final String? endDate;

  final String? cover;
  final String? index; // The ID used to fetch daily content

  Lesson({
    this.id,
    this.title,
    this.startDate,
    this.endDate,
    this.cover,
    this.index,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
}
