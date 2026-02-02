import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sda_lesson_app/models/quarterly.dart';
import 'package:sda_lesson_app/models/lesson.dart';
import 'package:sda_lesson_app/models/lesson_content.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:developer'; 

final apiProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio();
  
  // 1. URLS - SWITCHED TO V2 as default for Public API
  static const String _localProxy = 'http://127.0.0.1:8787';
  // ✅ CHANGED: Pointing to v2 to get "Alive in Jesus" content
  static const String _publicApi = 'https://sabbath-school.adventech.io/api/v2'; 

  // 2. DYNAMIC BASE URL
  String get baseUrl {
    if (kIsWeb) return _localProxy;
    if (Platform.isAndroid || Platform.isIOS) return _publicApi;
    return _localProxy;
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // 3. GET QUARTERLIES (Robust V2 Support)
  Future<List<Quarterly>> getQuarterlies(String lang) async {
    try {
      // Construct URL: .../api/v2/en/quarterlies/index.json
      String url = (baseUrl == _publicApi) 
          ? '$baseUrl/$lang/quarterlies/index.json' 
          : '$baseUrl/quarterlies/$lang';
          
      log("📡 Fetching Quarterlies from: $url");
      
      final response = await _dio.get(url);
      var rawData = response.data;

      // Handle String response (common in some http clients)
      if (rawData is String) {
        rawData = json.decode(rawData);
      }

      List<dynamic> listData = [];

      // ✅ V2 HANDLE: Sometimes V2 returns { "quarterlies": [...] } instead of just [...]
      if (rawData is Map && rawData.containsKey('quarterlies')) {
        listData = rawData['quarterlies'];
      } else if (rawData is List) {
        listData = rawData;
      }

      return listData.map((e) => Quarterly.fromJson(e)).toList();
    } catch (e) {
      log("❌ Error fetching quarterlies: $e");
      throw Exception('Failed to fetch quarterlies: $e');
    }
  }

  // 4. FETCH LESSONS
  Future<List<Lesson>> fetchLessons(String quarterlyId) async {
    try {
      String cleanId = quarterlyId.contains('/') ? quarterlyId.split('/').last : quarterlyId;
      if (cleanId.startsWith('en-')) cleanId = cleanId.substring(3);
      
      String url = (baseUrl == _publicApi) 
          ? '$baseUrl/en/quarterlies/$cleanId/index.json' 
          : '$baseUrl/quarterly/en/$cleanId';
          
      final response = await _dio.get(url);
      
      // Handle parsing safely
      var rawData = response.data;
      if (rawData is String) rawData = json.decode(rawData);
      Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

      return (data['lessons'] as List? ?? []).map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 5. FETCH QUARTERLY DETAILS (Alive in Jesus / PDF Check)
  Future<Map<String, dynamic>?> fetchQuarterlyDetailsWithFallback(String id) async {
    final client = http.Client();
    // Try V2 specifically for details as it has better metadata
    final url = '$_publicApi/en/quarterlies/$id/index.json';

    try {
      log("📡 Fetching details: $url");
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // PDF CHECK: If body starts with <, it's HTML (likely a PDF/404)
        if (response.body.trim().startsWith('<')) {
          return null; 
        }
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      log("Failed to fetch details: $e");
    } finally {
      client.close();
    }
    return null;
  }

  // 6. FETCH LESSON CONTENT
  Future<LessonContent> fetchLessonContent(String index) async {
    String cleanIndex = index.startsWith('/') ? index.substring(1) : index;
    List<String> parts = cleanIndex.split('/');
    String url;
    String lang = "en";
    String quarterlyId = "";
    String lessonId = "";

    // CONSTRUCT URL
    if (baseUrl == _publicApi && parts.length >= 3) {
      lang = parts[0];
      quarterlyId = parts[1];
      lessonId = parts[2];
      // strip lang prefix if exists (e.g. en-2025-01 -> 2025-01)
      if (quarterlyId.startsWith('$lang-')) quarterlyId = quarterlyId.substring(lang.length + 1);

      if (parts.length == 4) {
        url = "$baseUrl/$lang/quarterlies/$quarterlyId/lessons/$lessonId/days/${parts[3]}/read/index.json";
      } else {
        url = "$baseUrl/$lang/quarterlies/$quarterlyId/lessons/$lessonId/index.json";
      }
    } else {
      url = "$baseUrl/quarterly/$cleanIndex";
    }

    log("📡 Requesting content: $url");

    try {
      var response = await http.get(Uri.parse(url), headers: _headers);

      // FALLBACK LOGIC
      bool needsFallback = false;
      if (response.statusCode != 200 || response.body.trim().startsWith('<')) {
        needsFallback = true;
      } else {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          final tempContent = LessonContent.fromJson(data);
          bool hasContent = (tempContent.content?.isNotEmpty ?? false) || 
                            (tempContent.pdf?.isNotEmpty ?? false) || 
                            (tempContent.days?.isNotEmpty ?? false) ||
                            (tempContent.children?.isNotEmpty ?? false); // Check for children (new structure)

          if (!hasContent) needsFallback = true;
        } catch (e) {
          needsFallback = true;
        }
      }

      // TRY RESOURCE API FALLBACK
      if (needsFallback && parts.length >= 3) {
        String resourceUrl = "$baseUrl/$lang/resources/$quarterlyId/$lessonId/index.json";
        log("🔄 Switching to Resource API: $resourceUrl");
        final resResponse = await http.get(Uri.parse(resourceUrl), headers: _headers);
        if (resResponse.statusCode == 200 && !resResponse.body.trim().startsWith('<')) {
           response = resResponse;
        }
      }

      if (response.statusCode == 200) {
         if (response.body.trim().startsWith('<')) return LessonContent(days: [], title: "Content Unavailable");
         return LessonContent.fromJson(json.decode(response.body));
      }
      return LessonContent(days: [], title: "Error ${response.statusCode}");
    } catch (e) {
      return LessonContent(days: [], title: "Connection Error");
    }
  }
}