// lib/services/api_service.dart

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
  static const String _v2Api = 'https://sabbath-school.adventech.io/api/v2'; 

  // 2. DYNAMIC BASE URL
  String get baseUrl {
    if (kIsWeb) return _localProxy;
    if (Platform.isAndroid || Platform.isIOS) return _publicApi;
    return _localProxy;
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // 3. GET QUARTERLIES
  Future<List<Quarterly>> getQuarterlies(String lang) async {
    try {
      String url = (baseUrl == _publicApi) ? '$baseUrl/$lang/quarterlies/index.json' : '$baseUrl/quarterlies/$lang';
      final response = await _dio.get(url);
      List<dynamic> data = (response.data is String) ? json.decode(response.data) : response.data;
      return data.map((e) => Quarterly.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch quarterlies: $e');
    }
  }

  // 4. FETCH LESSONS
  Future<List<Lesson>> fetchLessons(String quarterlyId) async {
    try {
      String cleanId = quarterlyId.contains('/') ? quarterlyId.split('/').last : quarterlyId;
      if (cleanId.startsWith('en-')) cleanId = cleanId.substring(3);
      String url = (baseUrl == _publicApi) ? '$baseUrl/en/quarterlies/$cleanId/index.json' : '$baseUrl/quarterly/en/$cleanId';
      final response = await _dio.get(url);
      Map<String, dynamic> data = (response.data is String) ? json.decode(response.data) : Map<String, dynamic>.from(response.data);
      return (data['lessons'] as List? ?? []).map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 5. FETCH LESSON CONTENT (Corrected for Single Page Resources)
  Future<LessonContent> fetchLessonContent(String index) async {
    String cleanIndex = index.startsWith('/') ? index.substring(1) : index;
    List<String> parts = cleanIndex.split('/');
    String url;
    String lang = "en";
    String quarterlyId = "";
    String lessonId = "";

    // A. CONSTRUCT STANDARD V2 URL
    if (baseUrl == _publicApi && parts.length >= 3) {
      lang = parts[0];
      quarterlyId = parts[1];
      lessonId = parts[2];
      if (quarterlyId.startsWith('$lang-')) quarterlyId = quarterlyId.substring(lang.length + 1);

      if (parts.length == 4) {
        url = "$_v2Api/$lang/quarterlies/$quarterlyId/lessons/$lessonId/days/${parts[3]}/read/index.json";
      } else {
        url = "$_v2Api/$lang/quarterlies/$quarterlyId/lessons/$lessonId/index.json";
      }
    } else {
      url = "$baseUrl/quarterly/$cleanIndex";
    }

    print("📡 Fetching Standard Content: $url");

    try {
      var response = await http.get(Uri.parse(url), headers: _headers);

      // ============================================================
      // 🚀 THE FIX: DETECT IF CONTENT IS MISSING
      // ============================================================
      bool needsFallback = false;

      if (response.statusCode != 200 || response.body.trim().startsWith('<')) {
        needsFallback = true;
      } else {
        // Even if 200 OK, check if the actual text content is missing
        final Map<String, dynamic> data = json.decode(response.body);
        final tempContent = LessonContent.fromJson(data);
        
        // If NO content text AND NO PDF -> It's effectively empty
        if ((tempContent.content == null || tempContent.content!.isEmpty) && 
            (tempContent.pdf == null)) {
           print("⚠️ Standard API returned empty data.");
           needsFallback = true;
        }
      }

      // ============================================================
      // ♻️ FALLBACK: TRY RESOURCE API (Where Single Page Lessons Live)
      // ============================================================
      if (needsFallback && parts.length >= 3) {
        // Resource URL format: .../resources/quarterly/lesson/index.json
        String resourceUrl = "$_v2Api/$lang/resources/$quarterlyId/$lessonId/index.json";
        print("🔄 Trying Resource API: $resourceUrl");
        
        final resourceResponse = await http.get(Uri.parse(resourceUrl), headers: _headers);
        
        if (resourceResponse.statusCode == 200 && !resourceResponse.body.trim().startsWith('<')) {
           response = resourceResponse; // ✅ Success! Use this response.
           print("✅ Resource API success!");
        }
      }

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<')) {
           return LessonContent(days: [], title: "No Text Content"); 
        }
        final Map<String, dynamic> data = json.decode(response.body);
        return LessonContent.fromJson(data);
      } else {
        return LessonContent(days: [], title: "Error");
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      return LessonContent(days: [], title: "Error loading content");
    }
  }
}