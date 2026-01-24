import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- 1. DATA MODEL ---
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
    try {
      // Helper to safely parse int from String or Int
      int parseInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 1;
        return 1;
      }

      return DevotionalDay(
        id: json['id']?.toString() ?? '',
        month: parseInt(json['month']),
        day: parseInt(json['day']),
        title: json['title']?.toString() ?? 'No Title',
        verse: json['verse']?.toString() ?? '',
        // Matches the "verse_ref" key from Python script
        verseRef: json['verse_ref']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
      );
    } catch (e) {
      print("⚠️ Error parsing reading ID: ${json['id']} -> $e");
      // Return a placeholder so the app doesn't crash entirely
      return DevotionalDay(
        id: 'error',
        month: 1,
        day: 1,
        title: 'Error Loading Day',
        verse: '',
        verseRef: '',
        content: 'There was an error loading this content.',
      );
    }
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
    'ctr',
    'Christ Triumphant',
    'assets/images/devotionals/ctr_cover.png',
  ),
  DevotionalBookInfo(
    'maranatha',
    'Maranatha',
    'assets/images/devotionals/mar_cover.png',
  ),
  DevotionalBookInfo(
    'cc',
    'Conflict and Courage',
    'assets/images/devotionals/cc_cover.png',
  ),
  DevotionalBookInfo(
    'flb',
    'The Faith I Live By',
    'assets/images/devotionals/flb_cover.png',
  ),
  DevotionalBookInfo(
    'fh',
    'From the Heart',
    'assets/images/devotionals/fh_cover.png',
  ),
  DevotionalBookInfo(
    'ag',
    'God’s Amazing Grace',
    'assets/images/devotionals/ag_cover.png',
  ),
  DevotionalBookInfo(
    'hb',
    'Homeward Bound',
    'assets/images/devotionals/hb_cover.png',
  ),
  DevotionalBookInfo(
    'hp',
    'In Heavenly Places',
    'assets/images/devotionals/hp_cover.png',
  ),
  DevotionalBookInfo(
    'blj',
    'To Be Like Jesus',
    'assets/images/devotionals/blj_cover.png',
  ),
  DevotionalBookInfo(
    'lhu',
    'Lift Him Up',
    'assets/images/devotionals/lhu_cover.png',
  ),
  DevotionalBookInfo(
    'ofc',
    'Our Father Cares',
    'assets/images/devotionals/ofc_cover.png',
  ),
  DevotionalBookInfo(
    'ohc',
    'Our High Calling',
    'assets/images/devotionals/ohc_cover.png',
  ),
  DevotionalBookInfo(
    'rc',
    'Reflecting Christ',
    'assets/images/devotionals/rc_cover.png',
  ),
  DevotionalBookInfo(
    'sd',
    'Sons and Daughters of God',
    'assets/images/devotionals/sd_cover.png',
  ),
  DevotionalBookInfo(
    'tdg',
    'This Day With God',
    'assets/images/devotionals/tdg_cover.png',
  ),
  DevotionalBookInfo(
    'tmk',
    'That I May Know Him',
    'assets/images/devotionals/tmk_cover.png',
  ),
  DevotionalBookInfo(
    'ul',
    'The Upward Look',
    'assets/images/devotionals/ul_cover.png',
  ),
  DevotionalBookInfo(
    'yrp',
    'Ye Shall Receive Power',
    'assets/images/devotionals/yrp_cover.png',
  ),
  // Add other books here...
];

// --- 3. THE PROVIDER (With Robust Error Handling) ---
final devotionalContentProvider =
    FutureProvider.family<List<DevotionalDay>, String>((ref, bookId) async {
      try {
        // Correct path based on your folder structure
        final path = 'assets/json/devotionals/$bookId.json';
        // print("📂 Loading: $path");

        final String response = await rootBundle.loadString(path);

        if (response.isEmpty) {
          print("❌ Error: JSON file is empty");
          return [];
        }

        final List<dynamic> data = json.decode(response);

        // Safely map data to objects
        final List<DevotionalDay> readings = [];
        for (var item in data) {
          readings.add(DevotionalDay.fromJson(item));
        }

        // print("✅ Successfully loaded ${readings.length} readings.");
        return readings;
      } catch (e, stack) {
        print("❌ FATAL ERROR loading '$bookId': $e");
        print(stack);
        return [];
      }
    });
