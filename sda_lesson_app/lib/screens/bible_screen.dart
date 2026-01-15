import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart';
import 'bible_chapter_screen.dart'; // Required for navigation fix

class BibleScreen extends ConsumerStatefulWidget {
  // NEW: Optional parameters for Deep Linking (e.g., from Daily Verse)
  final String? initialBook;
  final int? initialChapter;
  final int? targetVerse;

  const BibleScreen({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.targetVerse,
  });

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  final BibleApiService _apiService = BibleApiService();
  late Future<List<Map<String, dynamic>>> _booksFuture;

  // Filter State: 0 = All, 1 = OT, 2 = NT
  int _selectedFilterIndex = 0;

  // --- STRICT OT FILTER LIST ---
  // Using this Set ensures we filter accurately even if books are missing from the DB.
  // The IDs match the keys in your BibleApiService.
  static const Set<String> _otBookIds = {
    'Gen', 'Exod', 'Lev', 'Num', 'Deut', 'Josh', 'Judg', 'Ruth',
    '1Sam', '2Sam', '1Kgs', '2Kgs', '1Chr', '2Chr', 'Ezra', 'Neh', 'Esth',
    'Job', 'Ps', 'Prov', 'Eccl', 'Song', 'Isa', 'Jer', 'Lam', 'Ezek',
    'Dan', 'Hos', 'Joel', 'Amos', 'Obad', 'Jonah', 'Mic', 'Nah', 'Hab',
    'Zeph', 'Hag', 'Zech', 'Mal',
  };

  @override
  void initState() {
    super.initState();
    // fetchBooks already returns them in Chronological Order (Gen -> Rev)
    _booksFuture = _apiService.fetchBooks();

    // NEW: Check for Deep Link Navigation immediately
    if (widget.initialBook != null && widget.initialChapter != null) {
      _handleDeepLink();
    }
  }

  // --- NEW: Handle automatic navigation to a verse ---
  Future<void> _handleDeepLink() async {
    // Wait slightly for UI to settle
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Re-fetch books to resolve the Book Name (e.g. "Genesis") to ID (e.g. "Gen")
      final books = await _apiService.fetchBooks();
      
      final targetBook = books.firstWhere(
        (b) => b['name'].toString().toLowerCase() == widget.initialBook!.toLowerCase(),
        orElse: () => {},
      );

      if (targetBook.isNotEmpty) {
        String bookId = targetBook['id'];
        // Construct Chapter ID (e.g., "Gen.1")
        String chapterId = "$bookId.${widget.initialChapter}";

        if (mounted) {
          // Navigate directly to Reader
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BibleReaderScreen(
                chapterId: chapterId,
                reference: "${widget.initialBook} ${widget.initialChapter}",
                targetVerse: widget.targetVerse, // Highlight this verse
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Deep Link Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF7F4F2);
    const activeColor = Color(0xFF7D2D3B);
    final Color inactiveColor = isDark
        ? (Colors.grey[800] ?? Colors.grey)
        : (Colors.grey[300] ?? Colors.grey);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Holy Bible", style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Bible",
            onPressed: () {
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(api: _apiService),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- FILTER TABS ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterTab("All", 0, activeColor, inactiveColor, isDark),
                const SizedBox(width: 10),
                _buildFilterTab(
                  "Old Testament",
                  1,
                  activeColor,
                  inactiveColor,
                  isDark,
                ),
                const SizedBox(width: 10),
                _buildFilterTab(
                  "New Testament",
                  2,
                  activeColor,
                  inactiveColor,
                  isDark,
                ),
              ],
            ),
          ),

          // --- BOOK LIST ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _booksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final allBooks = snapshot.data ?? [];
                List<Map<String, dynamic>> displayedBooks = [];

                // --- ROBUST FILTERING LOGIC ---
                if (_selectedFilterIndex == 0) {
                  // ALL
                  displayedBooks = allBooks;
                } else if (_selectedFilterIndex == 1) {
                  // OT
                  displayedBooks = allBooks
                      .where((b) => _otBookIds.contains(b['id']))
                      .toList();
                } else {
                  // NT
                  displayedBooks = allBooks
                      .where((b) => !_otBookIds.contains(b['id']))
                      .toList();
                }

                if (displayedBooks.isEmpty) {
                  return Center(
                    child: Text(
                      "No books found.",
                      style: TextStyle(color: textColor),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: displayedBooks.length,
                  separatorBuilder: (c, i) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  itemBuilder: (context, index) {
                    final book = displayedBooks[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : const Color(0xFFE0E7FF),
                        child: Text(
                          book['abbreviation'] ?? "Bk",
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A237E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        book['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        book['nameLong'] ?? "",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: isDark ? Colors.grey : Colors.grey[400],
                      ),
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
          ),
        ],
      ),
    );
  }

  // Helper for the Pill Tabs
  Widget _buildFilterTab(
    String label,
    int index,
    Color activeColor,
    Color inactiveColor,
    bool isDark,
  ) {
    final bool isSelected = _selectedFilterIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

// --- SEARCH DELEGATE ---
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
    if (query.length < 3) {
      return const Center(child: Text("Type at least 3 characters..."));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      chapterId: item['chapterId'],
                      reference: item['reference'],
                      targetVerse: item['verseNum'] as int?,
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
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book, size: 60, color: Colors.grey),
        SizedBox(height: 10),
        Text("Search for keywords like 'Grace', 'Sabbath', 'Love'"),
      ],
    );
  }
}