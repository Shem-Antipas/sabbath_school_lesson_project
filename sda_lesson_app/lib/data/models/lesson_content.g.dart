// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LessonContent _$LessonContentFromJson(Map<String, dynamic> json) =>
    LessonContent(
      id: json['id'] as String?,
      title: json['title'] as String?,
      date: json['date'] as String?,
      content: json['content'] as String?,
      days: (json['days'] as List<dynamic>?)
          ?.map((e) => LessonDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LessonContentToJson(LessonContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'date': instance.date,
      'content': instance.content,
      'days': instance.days,
    };

LessonDay _$LessonDayFromJson(Map<String, dynamic> json) => LessonDay(
  id: json['id'] as String?,
  title: json['title'] as String?,
  date: json['date'] as String?,
  index: json['index'] as String?,
);

Map<String, dynamic> _$LessonDayToJson(LessonDay instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'date': instance.date,
  'index': instance.index,
};
