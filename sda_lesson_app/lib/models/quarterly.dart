import 'package:json_annotation/json_annotation.dart';

part 'quarterly.g.dart';

@JsonSerializable()
class Quarterly {
  final String id;
  final String title;
  final String description;

  @JsonKey(name: 'human_date')
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

  // --- ADD THIS GETTER TO FIX IMAGES ---
  String get fullCoverUrl {
    // 1. If the API already gives a full link (http...), use it.
    if (coverUrl.startsWith('http')) {
      return coverUrl;
    }

    // 2. Otherwise, construct the full URL using the official CDN.
    // The format is: https://sabbath-school.adventech.io/api/v1/<ID>/cover.png
    return "https://sabbath-school.adventech.io/api/v1/$id/cover.png";
  }
}
