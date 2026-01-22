import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- 1. DATA MODEL (Must match Python Script V4) ---
class DevotionalDay {
  final String id;
  final int month;
  final int day;
  final String title;
  final String verse;
  final String verseRef;
  final String content;

  DevotionalDay({
    required this.id,
    required this.month,
    required this.day,
    required this.title,
    required this.verse,
    required this.verseRef,
    required this.content,
  });

  factory DevotionalDay.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int from String or Int
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 1;
      return 1;
    }

    return DevotionalDay(
      id: json['id'] ?? '',
      // Ensure month/day are integers, even if JSON has them as strings
      month: parseInt(json['month']),
      day: parseInt(json['day']),
      title: json['title'] ?? 'No Title',
      verse: json['verse'] ?? '',
      // Matches the "verse_ref" key from Python script
      verseRef: json['verse_ref'] ?? '', 
      content: json['content'] ?? '',
    );
  }
}

// --- 2. BOOK INFO ---
class DevotionalBookInfo {
  final String id;
  final String title;
  final String imagePath;

  DevotionalBookInfo(this.id, this.title, this.imagePath);
}

final List<DevotionalBookInfo> availableDevotionals = [
  DevotionalBookInfo(
    'maranatha', 
    'Maranatha', 
    'assets/images/devotionals/mar_cover.png' // Matches your uploaded file
  ),
  // Add other books here...
];

// --- 3. THE PROVIDER (With Debugging) ---
final devotionalContentProvider = FutureProvider.family<List<DevotionalDay>, String>((ref, bookId) async {
  try {
    // ⚠️ IMPORTANT: Matches the folder where you said you put the file
    final path = 'assets/json/devotionals/$bookId.json'; 
    print("📂 Loading: $path");

    final String response = await rootBundle.loadString(path);
    final List<dynamic> data = json.decode(response);
    
    print("✅ Parsed ${data.length} readings.");
    
    if (data.isNotEmpty) {
      print("🔎 Sample Reading: ${data.first}");
    }

    return data.map((e) => DevotionalDay.fromJson(e)).toList();
  } catch (e) {
    print("❌ Error loading devotional '$bookId': $e");
    return [];
  }
});