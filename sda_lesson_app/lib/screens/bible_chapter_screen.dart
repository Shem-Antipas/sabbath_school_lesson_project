import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart'; // We will create this next

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
    return Scaffold(
      appBar: AppBar(
        title: Text(bookName),
        centerTitle: true,
        actions: [
          // SEARCH BUTTON
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                // We pass the current bookId so user can search inside THIS book
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
            return Center(child: Text("Error: ${snapshot.error}"));
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BibleReaderScreen(
                        chapterId: chapter['id'], // e.g., "GEN.1"
                        reference: chapter['reference'], // e.g., "Genesis 1"
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12), // Softer corners
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapter['number'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade800,
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

// --- SEARCH LOGIC ---
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
      // Search inside the current book by default.
      // You can change 'bookId' to 'ALL' to search everywhere.
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
              subtitle: Text(item['text'] ?? ""),
              onTap: () {
                // Optional: Navigate to that verse
                // You would need to parse the reference to get the chapter ID
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
