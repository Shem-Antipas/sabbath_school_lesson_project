import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sda_lesson_app/models/quarterly.dart';
import 'package:sda_lesson_app/models/lesson.dart';
import 'package:sda_lesson_app/models/lesson_content.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

final apiProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio();

  // 1. URLS
  static const String _localProxy = 'http://127.0.0.1:8787';
  static const String _publicApi = 'https://sabbath-school.adventech.io/api/v1';

  // 2. DYNAMIC BASE URL
  String get baseUrl {
    if (kIsWeb) return _localProxy;
    if (Platform.isAndroid || Platform.isIOS) return _publicApi;
    return _localProxy;
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // 3. GET QUARTERLIES (Updated with Type Check)
  Future<List<Quarterly>> getQuarterlies(String lang) async {
    try {
      String url;
      if (baseUrl == _publicApi) {
        url = '$baseUrl/$lang/quarterlies/index.json';
      } else {
        url = '$baseUrl/quarterlies/$lang';
      }

      print("🔍 Fetching Quarterlies from: $url");
      final response = await _dio.get(url);

      // FIX: Check if response is String or List
      List<dynamic> data;
      if (response.data is String) {
        data = json.decode(response.data);
      } else {
        data = response.data;
      }

      return data.map((e) => Quarterly.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch quarterlies: $e');
    }
  }

  // 4. FETCH LESSONS (Crash Fixed Here)
  Future<List<Lesson>> fetchLessons(String quarterlyId) async {
    try {
      String cleanId = quarterlyId.contains('/')
          ? quarterlyId.split('/').last
          : quarterlyId;

      String url;
      if (baseUrl == _publicApi) {
        url = '$baseUrl/en/quarterlies/$cleanId/lessons.json';
      } else {
        url = '$baseUrl/quarterly/en/$cleanId';
      }

      print("🔍 Fetching Lesson List: $url");

      final response = await _dio.get(url);

      // --- CRASH FIX START ---
      Map<String, dynamic> data;

      // 1. If Dio returns a String (raw JSON), decode it manually
      if (response.data is String) {
        data = json.decode(response.data);
      }
      // 2. If Dio returns a Map (already parsed), just cast it
      else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        throw Exception("Unexpected data type: ${response.data.runtimeType}");
      }
      // --- CRASH FIX END ---

      final List<dynamic> lessonsList = data['lessons'] ?? [];

      return lessonsList.map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching lesson list: $e");
      rethrow;
    }
  }

  // 5. FETCH CONTENT
  Future<LessonContent> fetchLessonContent(String index) async {
    final String cleanIndex = index.startsWith('/')
        ? index.substring(1)
        : index;

    String url;
    if (baseUrl == _publicApi) {
      url = "$baseUrl/$cleanIndex/index.json";
    } else {
      url = "$baseUrl/quarterly/$cleanIndex";
    }

    print("📡 Fetching Lesson Content: $url");

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        if (response.body.contains("<!DOCTYPE html>")) {
          throw Exception("Server returned HTML. Lesson not found.");
        }

        final Map<String, dynamic> data = json.decode(response.body);
        return LessonContent.fromJson(data);
      } else {
        // Fallback Logic
        print("⚠️ Primary fetch failed, trying fallback...");

        final String prodUrl =
            "https://sabbath-school.adventech.io/api/v1/$cleanIndex/index.json";

        if (url == prodUrl) {
          throw Exception(
            'Failed to load lesson content: ${response.statusCode}',
          );
        }

        final prodResponse = await http.get(
          Uri.parse(prodUrl),
          headers: _headers,
        );

        if (prodResponse.statusCode == 200) {
          return LessonContent.fromJson(json.decode(prodResponse.body));
        }

        throw Exception(
          'Failed to load lesson content: ${response.statusCode}',
        );
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      rethrow;
    }
  }
}
