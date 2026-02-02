import 'package:flutter/material.dart';
import '../providers/devotional_provider.dart';
import '../screens/devotional_reader_screen.dart';

class LocalDevotionalSearchDelegate extends SearchDelegate {
  final List<DevotionalDay> allReadings;
  final String bookId;
  final String bookTitle;
  final String coverImagePath; // ✅ Added to support Reader Screen

  LocalDevotionalSearchDelegate({
    required this.allReadings,
    required this.bookId,
    required this.bookTitle,
    required this.coverImagePath, // ✅ Required in constructor
  });

  // ✅ Theme Support for Search Bar
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

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final cleanQuery = query.toLowerCase().trim();
    
    // Show empty state if no query
    if (cleanQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Search titles or content...",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Filter results
    final results = allReadings.where((day) {
      return day.title.toLowerCase().contains(cleanQuery) ||
          day.content.toLowerCase().contains(cleanQuery) || 
          day.verse.toLowerCase().contains(cleanQuery);
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text("No matches found."));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          title: Text(
            "${_getMonthName(item.month)} ${item.day}: ${item.title}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _getSnippet(item.content, cleanQuery),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
          ),
          onTap: () {
            // ✅ Navigate to Reader with Image & Highlight
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DevotionalReaderScreen(
                  bookId: bookId,
                  bookTitle: bookTitle,
                  coverImagePath: coverImagePath, // ✅ PASSED HERE
                  monthIndex: item.month,
                  monthName: _getMonthName(item.month),
                  initialDay: item.day,
                  searchQuery: query, // ✨ Highlight Logic
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to extract a relevant snippet of text around the search term
  String _getSnippet(String text, String query) {
    if (query.isEmpty) return text;
    
    int idx = text.toLowerCase().indexOf(query.toLowerCase());
    
    // If not found in content (maybe found in title), just show start of content
    if (idx == -1) {
      return text.length > 80 ? "${text.substring(0, 80)}..." : text;
    }

    // Calculate start and end indices for the snippet
    int start = (idx - 20).clamp(0, text.length);
    int end = (idx + query.length + 60).clamp(0, text.length);
    
    String snippet = text.substring(start, end);
    
    // Add ellipses if truncated
    if (start > 0) snippet = "...$snippet";
    if (end < text.length) snippet = "$snippet...";
    
    return snippet;
  }

  String _getMonthName(int m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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