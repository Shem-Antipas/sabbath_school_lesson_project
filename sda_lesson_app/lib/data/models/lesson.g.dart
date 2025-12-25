// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
  id: json['id'] as String?,
  title: json['title'] as String?,
  startDate: json['start_date'] as String?,
  endDate: json['end_date'] as String?,
  cover: json['cover'] as String?,
  index: json['index'] as String?,
);

Map<String, dynamic> _$LessonToJson(Lesson instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'start_date': instance.startDate,
  'end_date': instance.endDate,
  'cover': instance.cover,
  'index': instance.index,
};
