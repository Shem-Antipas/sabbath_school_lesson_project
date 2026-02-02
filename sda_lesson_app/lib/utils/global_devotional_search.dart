import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/devotional_provider.dart';
import '../screens/devotional_reader_screen.dart';
import '../screens/devotional_daily_list_screen.dart';

class GlobalDevotionalSearchDelegate extends SearchDelegate {
  
  // ✅ Theme Support for Search Bar (Matches Local Search)
  @override
  ThemeData appBarTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
        border: InputBorder.none,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? Colors.white : Colors.black,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
        ),
      ),
    );
  }

  // 1. Suggestions: Instant Book Title Matches
  @override
  Widget buildSuggestions(BuildContext context) {
    final cleanQuery = query.toLowerCase();

    // Filter Book Titles
    final bookMatches = availableDevotionals.where((book) {
      return book.title.toLowerCase().contains(cleanQuery);
    }).toList();

    return ListView(
      children: [
        if (cleanQuery.isNotEmpty && bookMatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "BOOKS",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),

        // Show Book Suggestions
        ...bookMatches.map(
          (book) => ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                book.imagePath,
                width: 30,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.book),
              ),
            ),
            title: Text(book.title),
            onTap: () {
              // Open that Book
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DevotionalDailyListScreen(
                    bookId: book.id,
                    bookTitle: book.title,
                    coverImagePath: book.imagePath, // ✅ PASSED IMAGE
                    monthIndex: 1, // Default to Jan
                    monthName: "January",
                  ),
                ),
              );
            },
          ),
        ),

        if (cleanQuery.isNotEmpty) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.manage_search, color: Colors.teal),
            title: Text("Search content for '$query' in ALL books"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showResults(context), // Trigger Deep Search
          ),
        ],
      ],
    );
  }

  // 2. Results: Deep Search in ALL files
  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty)
      return const Center(child: Text("Please enter a keyword."));

    return FutureBuilder<List<GlobalSearchResult>>(
      future: _performGlobalSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No matches found for '$query'"));
        }

        final results = snapshot.data!;

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  result.bookImage,
                  width: 35,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.book),
                ),
              ),
              title: Text(
                "${result.bookTitle}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    "${_getMonthName(result.dayData.month)} ${result.dayData.day}",
                     style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getSnippet(result.dayData.content, query),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // Navigate to Reader with Yellow Highlight
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DevotionalReaderScreen(
                      bookId: result.bookId,
                      bookTitle: result.bookTitle,
                      coverImagePath: result.bookImage, // ✅ PASSED IMAGE
                      monthIndex: result.dayData.month,
                      monthName: _getMonthName(result.dayData.month),
                      initialDay: result.dayData.day,
                      searchQuery: query, // ✨ Highlight Logic
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Logic Helpers ---

  Future<List<GlobalSearchResult>> _performGlobalSearch(String keyword) async {
    final List<GlobalSearchResult> matches = [];
    final lowerKey = keyword.toLowerCase().trim();

    for (var book in availableDevotionals) {
      try {
        // Load every book one by one
        final String jsonString = await rootBundle.loadString(
          'assets/json/devotionals/${book.id}.json',
        );
        final List<dynamic> jsonData = json.decode(jsonString);

        for (var item in jsonData) {
          final day = DevotionalDay.fromJson(item);
          if (day.content.toLowerCase().contains(lowerKey) ||
              day.title.toLowerCase().contains(lowerKey) ||
              day.verse.toLowerCase().contains(lowerKey)) {
            matches.add(
              GlobalSearchResult(
                bookId: book.id,
                bookTitle: book.title,
                bookImage: book.imagePath,
                dayData: day,
              ),
            );
          }
        }
      } catch (e) {
        /* ignore missing files */
      }
    }
    return matches;
  }

  String _getSnippet(String text, String query) {
    int idx = text.toLowerCase().indexOf(query.toLowerCase());
    if (idx == -1) return text.substring(0, (text.length > 50 ? 50 : text.length));
    
    int start = (idx - 20).clamp(0, text.length);
    int end = (idx + query.length + 60).clamp(0, text.length);
    
    String snippet = text.substring(start, end);
    if(start > 0) snippet = "...$snippet";
    if(end < text.length) snippet = "$snippet...";
    
    return snippet;
  }

  String _getMonthName(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : "";
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
}

class GlobalSearchResult {
  final String bookId;
  final String bookTitle;
  final String bookImage;
  final DevotionalDay dayData;
  GlobalSearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.bookImage,
    required this.dayData,
  });
}