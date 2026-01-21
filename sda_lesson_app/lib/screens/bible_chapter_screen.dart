import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import '../providers/bible_provider.dart';
import 'bible_reader_screen.dart';
import 'bible_verse_screen.dart'; 
import '../services/analytics_service.dart';

class BibleChapterScreen extends ConsumerWidget {
  final String bookId;    // Standard ID (e.g., "Gen", "Exod")
  final String bookName;  // Localized Name (e.g., "Mwanzo", "Wuok")

  const BibleChapterScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single instance for efficiency
    final BibleApiService apiService = BibleApiService();

    // Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFFBFBFD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // ✅ TITLE: Displays Localized Name ("Mwanzo")
        title: Text(bookName, style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // ✅ Get current version from provider (e.g., Luo, Swahili)
              final currentVersion = ref.read(bibleVersionProvider);
              
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(
                  api: apiService,
                  searchVersion: currentVersion, 
                  // ✅ Pass Standard ID to filter DB queries correctly
                  initialBookId: bookId, 
                  initialBookName: bookName,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // ✅ API CALL: Uses Standard ID ("Gen") to fetch chapters
        future: apiService.fetchChapters(bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error loading chapters.", style: TextStyle(color: textColor)),
            );
          }

          final chapters = snapshot.data ?? [];
          // Remove non-numeric chapters if any exist (e.g., "intro")
          final filteredChapters = chapters.where((c) => int.tryParse(c['number'].toString()) != null).toList();

          if (filteredChapters.isEmpty) {
             return Center(child: Text("No chapters found.", style: TextStyle(color: textColor)));
          }

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
              final chapterNum = chapter['number'].toString();

              return InkWell(
                onTap: () {
                  AnalyticsService().logReadBible(
                    book: bookName, // Log readable name
                    chapter: int.tryParse(chapterNum) ?? 1, 
                  );      
                  
                  // Navigate to Verse Selection
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BibleVerseScreen(
                        bookId: bookId,       // Pass Standard ID ("Gen")
                        bookName: bookName,   // Pass Display Name ("Mwanzo")
                        chapterId: chapter['id'], // e.g., "Gen.1"
                        chapterNumber: chapterNum,
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
                    chapterNum,
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

// --- UPDATED SEARCH DELEGATE ---
class BibleSearchDelegate extends SearchDelegate {
  final BibleApiService api;
  final BibleVersion searchVersion; 
  final String initialBookId;   // Standard ID ("Gen")
  final String initialBookName; // Display Name ("Mwanzo")

  BibleSearchDelegate({
    required this.api, 
    required this.searchVersion,
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
      // ✅ SEARCH: Filters by Standard ID ("Gen") in the selected Version
      future: api.searchBible(query, bookId: initialBookId, version: searchVersion),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text("No results for '$query' in $initialBookName"),
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
                item['reference'] ?? "Unknown", // "Mwanzo 1:1"
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                item['text'] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                int? targetVerse = int.tryParse(item['verseNum'].toString());

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      chapterId: item['chapterId'], // "Gen.1"
                      reference: item['reference'], // "Mwanzo 1:1"
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
        // Display what we are searching (e.g. "Searching Mwanzo in Swahili")
        Text("Searching $initialBookName in ${searchVersion.label}"),
      ],
    );
  }
}