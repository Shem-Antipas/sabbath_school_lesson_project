import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hymnal.dart';

// Provider to load the JSON file
final hymnsProvider = FutureProvider<List<Hymn>>((ref) async {
  final String response = await rootBundle.loadString('assets/hymns.json');
  final List<dynamic> data = json.decode(response);
  return data.map((json) => Hymn.fromJson(json)).toList();
});

// StateProvider to track the user's search query
final hymnSearchQueryProvider = StateProvider<String>((ref) => "");

// Provider to handle the filtering logic automatically
final filteredHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final hymnsAsync = ref.watch(hymnsProvider);
  final query = ref.watch(hymnSearchQueryProvider).toLowerCase();

  return hymnsAsync.whenData((hymns) {
    if (query.isEmpty) return hymns;
    return hymns
        .where(
          (h) =>
              h.title.toLowerCase().contains(query) ||
              h.id.toString().contains(query),
        )
        .toList();
  });
});
