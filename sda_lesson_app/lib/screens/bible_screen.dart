import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart';
import 'bible_chapter_screen.dart'; 
import '../providers/bible_provider.dart'; 

class BibleScreen extends ConsumerStatefulWidget {
  // Optional parameters for Deep Linking
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
  // Initialize the API Service
  final BibleApiService _apiService = BibleApiService();
  late Future<List<Map<String, dynamic>>> _booksFuture;

  // Filter State: 0 = All, 1 = OT, 2 = NT
  int _selectedFilterIndex = 0;

  // --- STRICT OT FILTER LIST ---
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
    // Load books initially (Defaults to KJV English names)
    final initialVersion = ref.read(bibleVersionProvider);
    _booksFuture = _apiService.fetchBooks(version: initialVersion);

    // Check for Deep Link Navigation immediately
    if (widget.initialBook != null && widget.initialChapter != null) {
      _handleDeepLink();
    }
  }

  // --- Handle automatic navigation to a verse ---
  Future<void> _handleDeepLink() async {
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final books = await _apiService.fetchBooks();
      
      final targetBook = books.firstWhere(
        (b) => b['name'].toString().toLowerCase() == widget.initialBook!.toLowerCase(),
        orElse: () => {},
      );

      if (targetBook.isNotEmpty) {
        String bookId = targetBook['id'];
        String chapterId = "$bookId.${widget.initialChapter}";

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BibleReaderScreen(
                chapterId: chapterId,
                reference: "${widget.initialBook} ${widget.initialChapter}",
                targetVerse: widget.targetVerse, 
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
    // ✅ 1. WATCH THE SELECTED VERSION
    final currentVersion = ref.watch(bibleVersionProvider);

    // ✅ 2. LISTEN FOR VERSION CHANGES (Logic Added Here)
    // This forces the book list (Genesis -> Chakruok) to update immediately
    ref.listen<BibleVersion>(bibleVersionProvider, (previous, next) {
      setState(() {
        _booksFuture = _apiService.fetchBooks(version: next);
      });
    });

    // Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2);
    const activeColor = Color(0xFF7D2D3B);
    final Color inactiveColor = isDark ? (Colors.grey[800] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // ✅ 3. TITLE SHOWS VERSION LABEL
        title: Column(
          children: [
            Text("Holy Bible", style: TextStyle(color: textColor)),
            Text(
              currentVersion.label, // e.g., "Dholuo"
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search Bible",
            onPressed: () {
              // ✅ Pass the current version to the search delegate
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(
                  api: _apiService, 
                  searchVersion: currentVersion, 
                ), 
              );
            },
          ),
          // ✅ 4. TRANSLATE BUTTON
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: "Switch Version",
            onPressed: () => _showVersionSheet(context),
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
                _buildFilterTab("Old Testament", 1, activeColor, inactiveColor, isDark),
                const SizedBox(width: 10),
                _buildFilterTab("New Testament", 2, activeColor, inactiveColor, isDark),
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

                // Logic to filter OT vs NT
                if (_selectedFilterIndex == 0) {
                  displayedBooks = allBooks;
                } else if (_selectedFilterIndex == 1) {
                  displayedBooks = allBooks.where((b) => _otBookIds.contains(b['id'])).toList();
                } else {
                  displayedBooks = allBooks.where((b) => !_otBookIds.contains(b['id'])).toList();
                }

                if (displayedBooks.isEmpty) {
                  return Center(
                    child: Text("No books found.", style: TextStyle(color: textColor)),
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
                        backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE0E7FF),
                        child: Text(
                          book['abbreviation'] ?? "Bk",
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white : const Color(0xFF1A237E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        book['name'], // ✅ Displays "Chakruok" if Luo is selected
                        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: Text(
                        book['nameLong'] ?? "",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.grey : Colors.grey[400]),
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

  // Helper Widget for Tabs
  Widget _buildFilterTab(String label, int index, Color activeColor, Color inactiveColor, bool isDark) {
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
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 5. BOTTOM SHEET FOR SELECTING VERSIONS
  void _showVersionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final current = ref.watch(bibleVersionProvider);
            
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Bible Version",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: BibleVersion.values.map((version) {
                        final isSelected = current == version;
                        return ListTile(
                          title: Text(version.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(version == BibleVersion.kjv ? "Standard Edition" : "Offline Translation"),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Color(0xFF7D2D3B)) 
                              : null,
                          onTap: () {
                            ref.read(bibleVersionProvider.notifier).state = version;
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}

// --- SEARCH DELEGATE ---
class BibleSearchDelegate extends SearchDelegate {
  final BibleApiService api;
  final BibleVersion searchVersion;
  
  BibleSearchDelegate({required this.api, required this.searchVersion});

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
      // ✅ CRITICAL FIX: Use the selected version for searching
      future: api.searchBible(query, bookId: 'ALL', version: searchVersion),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No results found in ${searchVersion.label}."));
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
                int? targetVerse = int.tryParse(item['verseNum'].toString());

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      chapterId: item['chapterId'],
                      reference: item['reference'],
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
        const Icon(Icons.menu_book, size: 60, color: Colors.grey),
        const SizedBox(height: 10),
        // ✅ UX: Shows the user what version they are searching
        Text("Searching in ${searchVersion.label}"),
      ],
    );
  }
}