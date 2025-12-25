import 'package:json_annotation/json_annotation.dart';

part 'quarterly.g.dart'; // This line will show an error until we generate code

@JsonSerializable()
class Quarterly {
  final String id;
  final String title;
  final String description;

  @JsonKey(name: 'human_date') // Maps JSON 'human_date' to dart 'humanDate'
  final String humanDate;

  @JsonKey(name: 'cover')
  final String coverUrl;

  Quarterly({
    required this.id,
    required this.title,
    required this.description,
    required this.humanDate,
    required this.coverUrl,
  });

  factory Quarterly.fromJson(Map<String, dynamic> json) =>
      _$QuarterlyFromJson(json);
}
