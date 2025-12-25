// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quarterly.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quarterly _$QuarterlyFromJson(Map<String, dynamic> json) => Quarterly(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  humanDate: json['human_date'] as String,
  coverUrl: json['cover'] as String,
);

Map<String, dynamic> _$QuarterlyToJson(Quarterly instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'human_date': instance.humanDate,
  'cover': instance.coverUrl,
};
