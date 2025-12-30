import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart'; // Ensure this import is correct
import 'bible_chapter_screen.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We instantiate the service to pass it to the search delegate
    final BibleApiService apiService = BibleApiService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Holy Bible"),
        centerTitle: true,
        actions: [
          // 1. THE SEARCH BUTTON
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Bible",
            onPressed: () {
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(api: apiService),
              );
            },
          ),
        ],
      ),
      // ... (Your existing Body code for the List of Books remains here) ...
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: apiService.fetchBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final books = snapshot.data ?? [];

          return ListView.separated(
            itemCount: books.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0E7FF),
                  child: Text(
                    book['abbreviation'] ?? "Bk",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                title: Text(
                  book['name'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(book['nameLong'] ?? ""),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BibleChapterScreen(
                        bookId: book['id'],
                        bookName: book['name'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- SEARCH DELEGATE IMPLEMENTATION ---
class BibleSearchDelegate extends SearchDelegate {
  final BibleApiService api;
  BibleSearchDelegate({required this.api});

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
    if (query.length < 3)
      return const Center(child: Text("Type at least 3 characters..."));

    return FutureBuilder<List<Map<String, dynamic>>>(
      // Searches the entire Bible ('ALL')
      future: api.searchBible(query, bookId: 'ALL'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No verses found."));
        }

        final results = snapshot.data!;

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              title: Text(
                item['reference'] ?? "Unknown",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              subtitle: Text(
                item['text'] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // 2. NAVIGATE TO READER ON TAP
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      chapterId: item['chapterId'], // API returns this!
                      reference: item['reference'], // e.g. "Genesis 1:1"
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
        const Icon(Icons.menu_book, size: 60, color: Colors.grey),
        const SizedBox(height: 10),
        const Text("Search for keywords like 'Grace', 'Sabbath', 'Love'"),
      ],
    );
  }
}
