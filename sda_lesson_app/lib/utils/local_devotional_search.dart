import 'package:flutter/material.dart';
import '../providers/devotional_provider.dart';
import '../screens/devotional_reader_screen.dart';

class LocalDevotionalSearchDelegate extends SearchDelegate {
  final List<DevotionalDay> allReadings;
  final String bookId;
  final String bookTitle;

  LocalDevotionalSearchDelegate({
    required this.allReadings,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return const SizedBox();

    final results = allReadings.where((day) {
      return day.title.toLowerCase().contains(cleanQuery) ||
          day.content.toLowerCase().contains(cleanQuery);
    }).toList();

    if (results.isEmpty) return const Center(child: Text("No matches found."));

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          title: Text(
            "${_getMonthName(item.month)} ${item.day}: ${item.title}",
          ),
          subtitle: Text(
            _getSnippet(item.content, cleanQuery),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            // Navigate to Reader with Yellow Highlight
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DevotionalReaderScreen(
                  bookId: bookId,
                  bookTitle: bookTitle,
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

  String _getSnippet(String text, String query) {
    int idx = text.toLowerCase().indexOf(query.toLowerCase());
    if (idx == -1) return text.substring(0, 50);
    int start = (idx - 20).clamp(0, text.length);
    int end = (idx + 60).clamp(0, text.length);
    return "...${text.substring(start, end)}...";
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
