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
      // ... (cleaning ID logic) ...
      String cleanId = quarterlyId.contains('/')
          ? quarterlyId.split('/').last
          : quarterlyId;
      if (cleanId.startsWith('en-')) cleanId = cleanId.substring(3);

      String url;
      if (baseUrl == _publicApi) {
        // 1. USE index.json (The Quarterly File)
        url = '$baseUrl/en/quarterlies/$cleanId/index.json';
      } else {
        url = '$baseUrl/quarterly/en/$cleanId';
      }

      final response = await _dio.get(url);

      // ... (Error handling) ...

      Map<String, dynamic> data;
      if (response.data is String) {
        data = json.decode(response.data);
      } else {
        data = Map<String, dynamic>.from(response.data);
      }

      // 2. EXTRACT THE LIST
      // The file is NOT LessonContent. It is a map that *contains* a "lessons" list.
      final List<dynamic> lessonsList = data['lessons'] ?? [];

      return lessonsList.map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<LessonContent> fetchLessonContent(String index) async {
    String cleanIndex = index.startsWith('/') ? index.substring(1) : index;
    List<String> parts = cleanIndex.split('/');

    String url;

    if (baseUrl == _publicApi && parts.length >= 3) {
      String lang = parts[0];
      String quarterlyId = parts[1];
      String lessonId = parts[2];

      if (quarterlyId.startsWith('$lang-')) {
        quarterlyId = quarterlyId.substring(lang.length + 1);
      }

      // --- THE FIX IS HERE ---
      if (parts.length == 4) {
        String dayId = parts[3];
        // URL for specific day content (READING)
        url =
            "$baseUrl/$lang/quarterlies/$quarterlyId/lessons/$lessonId/days/$dayId/read/index.json";
      } else {
        // URL for lesson overview (MENU)
        url =
            "$baseUrl/$lang/quarterlies/$quarterlyId/lessons/$lessonId/index.json";
      }
      // -----------------------
    } else {
      url = "$baseUrl/quarterly/$cleanIndex";
    }

    print("📡 Fetching Lesson Content: $url");

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith("<!DOCTYPE html>")) {
          throw Exception("Server returned HTML. Check URL construction.");
        }
        final Map<String, dynamic> data = json.decode(response.body);
        return LessonContent.fromJson(data);
      } else {
        throw Exception('Failed to load content: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      rethrow;
    }
  }
}
