import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ Required for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Required for offline data

// --- API SERVICE IMPORTS ---
import '../services/api_service.dart';
import '../models/quarterly.dart';
import '../models/lesson_content.dart' as reader;
import '../models/lesson.dart';

// --- API SERVICE ---
final apiProvider = Provider((ref) => ApiService());

// --- QUARTERLIES (Adult Standard) ---
final quarterlyListProvider = FutureProvider<List<Quarterly>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getQuarterlies('en');
});

// --- LESSON LIST (Standard) ---
final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  quarterlyId,
) async {
  final api = ref.watch(apiProvider);
  return api.fetchLessons(quarterlyId);
});

// ✅ ALIAS: So DashboardScreen can find 'lessonListProvider'
final lessonListProvider = lessonsProvider;

// --- LESSON CONTENT (Merged & Optimized) ---
final lessonContentProvider = FutureProvider.autoDispose
    .family<reader.LessonContent, String>((ref, lessonIndex) async {
      final apiService = ref.watch(apiProvider);
      ref.keepAlive();
      
      try {
        debugPrint("📡 Requesting content for: $lessonIndex");

        final reader.LessonContent content = await apiService
            .fetchLessonContent(lessonIndex);

        if (content.days?.isEmpty ?? true) {
          debugPrint("⚠️ Warning: Lesson content loaded but 'days' list is null or empty.");
        }

        return content;
      } catch (e, stack) {
        debugPrint("❌ Provider Error for $lessonIndex: $e");
        debugPrint(stack.toString());
        if (e.toString().contains("empty") ||
            e.toString().contains("404") ||
            e.toString().contains("500")) {
          throw Exception(
            "The study material for this date ($lessonIndex) is not yet available on the server.",
          );
        }
        throw Exception(
          "Failed to load daily study. Please check your connection.",
        );
      }
    });

final navIndexProvider = StateProvider<int>((ref) => 0);

// ============================================================================
// ✅ ALIVE IN JESUS: LIST PROVIDER (With Caching & Offline Support)
// ============================================================================
final aliveInJesusListProvider = FutureProvider<List<dynamic>>((ref) async {
  const cacheKey = 'alive_in_jesus_cache_v2';
  final client = http.Client();
  
  try {
    // ---------------------------------------------------------
    // 1. ONLINE ATTEMPT (Try fetching fresh data)
    // ---------------------------------------------------------
    // Using V2 API which contains the new curriculum
    final urlV2 = 'https://sabbath-school.adventech.io/api/v2/en/quarterlies/index.json';
    debugPrint("🚀 Fetching Alive in Jesus List: $urlV2");
    
    final response = await client.get(Uri.parse(urlV2)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      // ✅ SUCCESS: Save this data to the phone for later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, response.body);
      
      return _processData(json.decode(response.body));
    }
  } catch (e) {
    debugPrint("⚠️ No Internet or API Error ($e). Switching to Offline Mode...");
  } finally {
    client.close();
  }

  // ---------------------------------------------------------
  // 2. OFFLINE FALLBACK (Load saved data)
  // ---------------------------------------------------------
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(cacheKey)) {
    final cachedString = prefs.getString(cacheKey);
    if (cachedString != null) {
      debugPrint("📂 Loaded Alive in Jesus from Local Cache");
      return _processData(json.decode(cachedString));
    }
  }

  // If we have no internet AND no cache, we have to fail
  throw Exception('No internet connection and no offline data found.');
});

// ============================================================================
// ✅ ALIVE IN JESUS: DETAILS PROVIDER (Prevents Crash on PDFs)
// ============================================================================
final aliveInJesusDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final client = http.Client();
  
  // List of potential URLs to try (V2 first, then V1)
  final urls = [
    'https://sabbath-school.adventech.io/api/v2/en/quarterlies/$id/index.json',
    'https://sabbath-school.adventech.io/api/v1/en/quarterlies/$id/index.json',
  ];

  for (final url in urls) {
    try {
      final response = await client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // ✅ CRITICAL FIX: Check if response is HTML (Error/404)
        // This happens when the item is a PDF file, not a lesson folder.
        if (response.body.trim().startsWith('<')) {
          debugPrint("⚠️ API returned HTML (likely 404/PDF) for $url");
          continue; 
        }
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Failed to fetch $url: $e");
    } finally {
      client.close();
    }
  }
  
  // If all attempts fail (or it's a PDF), return null so the UI shows the "Read Resource" button.
  return null;
});

// ============================================================================
// ✅ HELPER: Filter Data for Alive in Jesus
// ============================================================================
List<dynamic> _processData(dynamic decoded) {
  final List<dynamic> allItems = [];

  if (decoded is List) {
    allItems.addAll(decoded);
  } else if (decoded is Map && decoded.containsKey('quarterlies')) {
    allItems.addAll(decoded['quarterlies']);
  }

  // Filter for Alive in Jesus / Children's content
  return allItems.where((q) {
    final id = (q['id'] ?? '').toString().toLowerCase();
    final title = (q['title'] ?? '').toString().toLowerCase();
    final group = (q['quarterly_group'] ?? q['group'] ?? '').toString().toLowerCase();
    
    return group.contains('alive') || 
           title.contains('alive in jesus') ||
           id.contains('-bg') || // Beginner
           id.contains('-bb') || // Babies
           id.contains('-kd') || // Kindergarten
           id.contains('-pr') || // Primary
           title.contains('yaq');
  }).toList();
}