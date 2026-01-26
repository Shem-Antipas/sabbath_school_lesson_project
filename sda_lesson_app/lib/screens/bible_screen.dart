import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import '../providers/bible_provider.dart';
import '../utils/bible_sort_helper.dart'; // ✅ 1. Import the Helper
import 'bible_reader_screen.dart';
import 'bible_chapter_screen.dart'; 

class BibleScreen extends ConsumerStatefulWidget {
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
  int _selectedFilterIndex = 0;

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
    final initialVersion = ref.read(bibleVersionProvider);
    _booksFuture = _apiService.fetchBooks(version: initialVersion);

    if (widget.initialBook != null && widget.initialChapter != null) {
      _handleDeepLink();
    }
  }

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
    final currentVersion = ref.watch(bibleVersionProvider);

    ref.listen<BibleVersion>(bibleVersionProvider, (previous, next) {
      setState(() {
        _booksFuture = _apiService.fetchBooks(version: next);
      });
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2);
    const activeColor = Color(0xFF7D2D3B);
    final Color inactiveColor = isDark ? (Colors.grey[800] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text("Holy Bible", style: TextStyle(color: textColor)),
            Text(
              currentVersion.label, 
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
              showSearch(
                context: context,
                delegate: BibleSearchDelegate(
                  api: _apiService, 
                  searchVersion: currentVersion, 
                ), 
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: "Switch Version",
            onPressed: () => _showVersionSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
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
                        book['name'], 
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

// --- UPDATED SEARCH DELEGATE WITH SORTING ---
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

    // ✅ Return a Stateful Widget to handle Filter State
    return _SearchResultsView(
      api: api,
      searchVersion: searchVersion,
      query: query,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book, size: 60, color: Colors.grey),
        const SizedBox(height: 10),
        Text("Searching in ${searchVersion.label}"),
      ],
    );
  }
}

// ✅ NEW STATEFUL WIDGET FOR RESULTS & FILTERING
class _SearchResultsView extends StatefulWidget {
  final BibleApiService api;
  final BibleVersion searchVersion;
  final String query;

  const _SearchResultsView({
    required this.api,
    required this.searchVersion,
    required this.query,
  });

  @override
  State<_SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<_SearchResultsView> {
  String _selectedFilter = 'ALL'; // Options: ALL, OT, NT

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFF7D2D3B);
    final inactiveColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        // --- 1. FILTER TABS ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: isDark ? Colors.black12 : Colors.white,
          child: Row(
            children: [
              _buildFilterChip("All", 'ALL', activeColor, inactiveColor!, textColor),
              const SizedBox(width: 8),
              _buildFilterChip("Old Testament", 'OT', activeColor, inactiveColor, textColor),
              const SizedBox(width: 8),
              _buildFilterChip("New Testament", 'NT', activeColor, inactiveColor, textColor),
            ],
          ),
        ),
        const Divider(height: 1),

        // --- 2. RESULTS LIST ---
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            // ✅ Pass the _selectedFilter to the API
            future: widget.api.searchVerses(
              widget.query, 
              version: widget.searchVersion, 
              testament: _selectedFilter
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text("No results found in ${widget.searchVersion.label}."));
              }

              // Apply Chronological Sort
              final sortedResults = BibleSortHelper.sortResults(snapshot.data!);

              return ListView.builder(
                itemCount: sortedResults.length,
                itemBuilder: (context, index) {
                  final item = sortedResults[index];
                  return ListTile(
                    title: Text(
                      item['reference'] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7D2D3B),
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
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, Color activeColor, Color inactiveColor, Color textColor) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? activeColor : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : textColor.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}