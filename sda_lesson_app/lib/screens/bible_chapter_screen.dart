import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart';
import 'bible_verse_screen.dart'; 
import '../services/analytics_service.dart';

class BibleChapterScreen extends ConsumerWidget {
  final String bookId;
  final String bookName;

  const BibleChapterScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFFBFBFD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(bookName, style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(
                  initialBookId: bookId,
                  initialBookName: bookName,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: BibleApiService().fetchChapters(bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: textColor),
              ),
            );
          }

          final chapters = snapshot.data ?? [];
          final filteredChapters = chapters
              .where((c) => c['number'] != 'intro')
              .toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: filteredChapters.length,
            itemBuilder: (context, index) {
              final chapter = filteredChapters[index];

              return InkWell(
                onTap: () {
         AnalyticsService().logReadBible(
      book: bookName,
      chapter: int.parse(chapter['number'].toString()), 
    );      // Navigate to Verse Selection
                  Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BibleVerseScreen(
          bookId: bookId,
          bookName: bookName,
          chapterId: chapter['id'],
          chapterNumber: chapter['number'],
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.blue.shade100,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapter['number'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.blue.shade800,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- UPDATED SEARCH LOGIC ---
class BibleSearchDelegate extends SearchDelegate {
  final String initialBookId;
  final String initialBookName;
  final BibleApiService _api = BibleApiService();

  BibleSearchDelegate({
    required this.initialBookId,
    required this.initialBookName,
  });

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    if (query.length < 3) {
      return const Center(child: Text("Please enter at least 3 characters"));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _api.searchBible(query, bookId: initialBookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text("No results found in $initialBookName for '$query'"),
          );
        }

        final results = snapshot.data!;

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              title: Text(
                item['reference'] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                item['text'] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // ✅ THE FIX: Parse the verse number safely
                int? targetVerse = int.tryParse(item['verseNum'].toString());

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      chapterId: item['chapterId'],
                      reference: item['reference'],
                      // ✅ PASS IT HERE: This triggers the auto-scroll
                      targetVerse: targetVerse, 
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

  @override
  Widget buildSuggestions(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search, size: 50, color: Colors.grey),
        const SizedBox(height: 10),
        Text("Searching in $initialBookName"),
      ],
    );
  }
}