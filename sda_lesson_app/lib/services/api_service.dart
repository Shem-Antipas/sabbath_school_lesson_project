import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quarterly.dart';
import '../data/models/lesson.dart';
import '../data/models/lesson_content.dart';

final apiProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'http://127.0.0.1:8787';

  Future<List<Quarterly>> getQuarterlies(String lang) async {
    try {
      final response = await _dio.get('$baseUrl/quarterlies/$lang');
      final List<dynamic> data = response.data;
      return data.map((e) => Quarterly.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch quarterlies: $e');
    }
  }

  Future<List<Lesson>> fetchLessons(String quarterlyId) async {
    try {
      String cleanId = quarterlyId.contains('/')
          ? quarterlyId.split('/').last
          : quarterlyId;

      // Logic: /quarterly/en/2026-01
      final url = '$baseUrl/quarterly/en/$cleanId';

      print("🔍 Fetching Lesson List: $url");
      final response = await _dio.get(url);

      final List<dynamic> data = response.data['lessons'];
      return data.map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching lesson list: $e");
      rethrow;
    }
  }

  // --- THIS IS THE SECTION YOU ASKED ABOUT ---
  Future<LessonContent> fetchLessonContent(String lessonIndex) async {
    try {
      // lessonIndex comes in as "en/2026-01/01/01"
      final url = "$baseUrl/quarterly/$lessonIndex";

      print("📡 Fetching Day Content: $url");
      final response = await _dio.get(url);

      // Check if we accidentally got the Quarterly info (the list)
      // instead of the specific Day content (the reading text)
      if (response.data['quarterly'] != null &&
          response.data['content'] == null) {
        throw Exception(
          "Proxy returned Quarterly List instead of Day Content!",
        );
      }

      // Safety check: ensure 'content' exists
      if (response.data['content'] == null) {
        throw Exception(
          "The study material for this date is not yet available.",
        );
      }

      return LessonContent.fromJson(response.data);
    } catch (e) {
      print("❌ API Error: $e");
      rethrow;
    }
  }
}
  // ------------------------------------------