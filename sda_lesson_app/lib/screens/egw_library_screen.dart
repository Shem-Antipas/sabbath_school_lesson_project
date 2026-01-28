import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import '../models/book_meta.dart'; 
import 'egw_toc_screen.dart'; 
import 'egw_book_detail_screen.dart';
import '../services/analytics_service.dart'; // ✅ Imported

// --- PROVIDER FOR FILTERING ---
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

// --- MAIN SCREEN ---
class EGWLibraryScreen extends ConsumerStatefulWidget {
  const EGWLibraryScreen({super.key});

  @override
  ConsumerState<EGWLibraryScreen> createState() => _EGWLibraryScreenState();
}

class _EGWLibraryScreenState extends ConsumerState<EGWLibraryScreen> {
  List<BookMeta> _allBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  // Load the list of books from assets
  Future<void> _loadIndex() async {
    try {
      final String response = await rootBundle.loadString('assets/data/books_index.json');
      final List<dynamic> data = json.decode(response);
      
      if (mounted) {
        setState(() {
          _allBooks = data.map((json) => BookMeta.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading index: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    final favorites = ref.watch(favoritesProvider);
    final showOnlyFavorites = ref.watch(showFavoritesOnlyProvider);

    // Filter books based on favorite status
    final displayedBooks = showOnlyFavorites
        ? _allBooks.where((book) => favorites.contains(book.id)).toList()
        : _allBooks;

    double width = MediaQuery.of(context).size.width;
    int columnCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return WillPopScope(
      onWillPop: () async {
        if (showOnlyFavorites) {
          ref.read(showFavoritesOnlyProvider.notifier).state = false;
          return false; 
        }
        return true; 
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(showOnlyFavorites ? "Favorite Books" : "Spirit of Prophecy"),
          centerTitle: true,
          backgroundColor: isDark ? null : const Color(0xFF06275C),
          foregroundColor: isDark ? null : Colors.white,
          
          leading: showOnlyFavorites
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(showFavoritesOnlyProvider.notifier).state = false;
                  },
                )
              : null, 
          
          actions: [
            IconButton(
              icon: Icon(showOnlyFavorites ? Icons.bookmark : Icons.bookmark_border),
              tooltip: "Filter Favorites",
              onPressed: () => ref.read(showFavoritesOnlyProvider.notifier).state = !showOnlyFavorites,
            ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: "Toggle Theme",
              onPressed: () {
                final newTheme = isDark ? ThemeMode.light : ThemeMode.dark;
                ref.read(themeProvider.notifier).setTheme(newTheme);
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(
                context: context,
                delegate: EGWSearchDelegate(_allBooks),
              ),
            ),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: displayedBooks.isEmpty
                    ? Center(
                        child: Text(
                          showOnlyFavorites 
                            ? "No favorites yet." 
                            : "No books found.",
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          childAspectRatio: 0.7, 
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: displayedBooks.length,
                        itemBuilder: (context, index) {
                          return _buildBookTile(
                            context,
                            ref,
                            displayedBooks[index],
                            isDark,
                          );
                        },
                      ),
              ),
            ),
      ),
    );
  }

  Widget _buildBookTile(
    BuildContext context,
    WidgetRef ref,
    BookMeta book,
    bool isDark,
  ) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorited = favorites.contains(book.id);

    return GestureDetector(
      onTap: () {
        // ✅ ANALYTICS: Track opening a book from the library
        AnalyticsService().logReadEgw(
          bookTitle: book.title, 
          chapterTitle: "Table of Contents" // Default context
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EGWTableOfContentsScreen(bookMeta: book),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4, 
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.asset(
                      book.coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.book, color: Colors.white70, size: 40),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF06275C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: 20,
                constraints: const BoxConstraints(minWidth: 35, minHeight: 35),
                padding: EdgeInsets.zero,
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: isFavorited ? Colors.redAccent : Colors.white,
                ),
                onPressed: () => ref
                    .read(favoritesProvider.notifier)
                    .toggleFavorite(book.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- GLOBAL SEARCH DELEGATE ---
class EGWSearchDelegate extends SearchDelegate {
  final List<BookMeta> books;
  EGWSearchDelegate(this.books);

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
    if (query.isEmpty) return const SizedBox();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchAllBooks(context, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No matches found."));
        }

        final results = snapshot.data!;

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            final BookMeta book = result['book'];
            final String chapterTitle = result['chapterTitle'];
            final String snippet = result['snippet'];
            
            // ✅ FIX: Use the Chapter Index and Local Index
            final int chapterIdx = result['chapterIndex'];
            final int localIdx = result['localIndex'];

            return ListTile(
              leading: Image.asset(book.coverImage, width: 30, fit: BoxFit.cover),
              title: Text(book.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapterTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                // ✅ ANALYTICS
                // AnalyticsService().logReadEgw(...) 

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EGWBookDetailScreen(
                      bookMeta: book,
                      initialChapterIndex: chapterIdx, // Load specific chapter
                      initialIndex: localIdx,          // Scroll to specific paragraph
                      searchQuery: query,
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
    if (query.isEmpty) return const SizedBox();

    final results = books.where((book) {
      return book.title.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text("Books found:", style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final book = results[index];
                return ListTile(
                  leading: Image.asset(book.coverImage, width: 30),
                  title: Text(book.title),
                  onTap: () {
                     // Navigate to TOC
                     // Navigator.push(...)
                  },
                );
              },
            ),
          ),
        ] else 
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Press 'Enter' to search inside book content."),
          ),
      ],
    );
  }

  // --- HELPER: Full parsing logic restored ---
  Map<String, dynamic> _parseHtmlContent(String rawHtml) {
    String processed = rawHtml
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n'); 

    List<RangeStyle> boldRanges = [];
    StringBuffer cleanBuffer = StringBuffer();
    RegExp boldExp = RegExp(r'<b>(.*?)</b>', dotAll: true);
    
    String remaining = processed;
    while(remaining.isNotEmpty) {
      Match? match = boldExp.firstMatch(remaining);
      if (match != null) {
        cleanBuffer.write(remaining.substring(0, match.start));
        int start = cleanBuffer.length;
        cleanBuffer.write(match.group(1) ?? "");
        int end = cleanBuffer.length;
        boldRanges.add(RangeStyle(start: start, end: end, isBold: true));
        remaining = remaining.substring(match.end);
      } else {
        cleanBuffer.write(remaining);
        break;
      }
    }

    return {
      'text': cleanBuffer.toString(),
      'boldRanges': boldRanges,
    };
  }

  void _addResult(List<Map<String, dynamic>> list, String text, int localIndex, String chapterTitle, BookMeta book, String query, int chapterIndex) {
    int matchIndex = text.toLowerCase().indexOf(query);
    int start = (matchIndex - 20).clamp(0, text.length);
    int end = (matchIndex + query.length + 50).clamp(0, text.length);
    String snippet = "...${text.substring(start, end).replaceAll('\n', ' ')}...";

    list.add({
      'book': book,
      'chapterTitle': chapterTitle,
      'snippet': snippet,
      'chapterIndex': chapterIndex, // The Chapter to load
      'localIndex': localIndex,     // The exact item index within that chapter
    });
  }

  // --- UPDATED SEARCH LOGIC: CALCULATES LOCAL INDEX ---
  Future<List<Map<String, dynamic>>> _searchAllBooks(BuildContext context, String query) async {
    List<Map<String, dynamic>> searchResults = [];
    String lowerQuery = query.toLowerCase();

    for (var book in books) {
      try {
        final String response = await rootBundle.loadString(book.filePath);
        final Map<String, dynamic> data = json.decode(response);
        final List<dynamic> chapters = data['chapters'];

        for (int i = 0; i < chapters.length; i++) {
          String rawContent = chapters[i]['content'] ?? "";
          String title = chapters[i]['title'] ?? "";

          // ✅ KEY CHANGE: Reset Local Index for every chapter
          // In the Detail Screen, every chapter starts at index 0
          int localItemIndex = 0; 

          // 1. Header (Item 0)
          localItemIndex++; 

          // 2. Parse Content (Exact logic from Detail Screen)
          var parsed = _parseHtmlContent(rawContent);
          String fullCleanText = parsed['text'];
          List<RangeStyle> fullBoldRanges = parsed['boldRanges'];

          // 3. Split Paragraphs (Double Newline)
          List<String> hardParagraphs = fullCleanText.split('\n\n');
          int currentGlobalOffset = 0;

          for (String paragraph in hardParagraphs) {
            if (paragraph.trim().isEmpty) {
              currentGlobalOffset += paragraph.length + 2; 
              continue;
            }

            int chunkStart = currentGlobalOffset;
            int chunkEnd = chunkStart + paragraph.length;

            // 4. Split by Bold Ranges
            List<int> splitPoints = [];
            for (var r in fullBoldRanges) {
              if (r.start > chunkStart && r.start < chunkEnd) {
                splitPoints.add(r.start - chunkStart);
              }
            }
            splitPoints.sort();

            List<String> boldSplitChunks = [];
            int previousSplit = 0;
            for (int point in splitPoints) {
              boldSplitChunks.add(paragraph.substring(previousSplit, point).trim());
              previousSplit = point;
            }
            boldSplitChunks.add(paragraph.substring(previousSplit).trim());

            // 5. Split by Sentence Count (8-sentence rule)
            for (String chunk in boldSplitChunks) {
              if (chunk.isEmpty) continue;

              RegExp sentenceSplit = RegExp(r'(?<=[.?!])\s+');
              List<String> sentences = chunk.split(sentenceSplit);
              
              if (sentences.length <= 8) {
                // This chunk is a single BookItem
                if (chunk.toLowerCase().contains(lowerQuery)) {
                  _addResult(searchResults, chunk, localItemIndex, title, book, lowerQuery, i);
                }
                localItemIndex++; // ✅ Increment Local Index
              } else {
                // Chop longer paragraphs
                StringBuffer buffer = StringBuffer();
                int sentenceCount = 0;
                for (String s in sentences) {
                   buffer.write(s.trim());
                   buffer.write(" "); 
                   sentenceCount++;
                   
                   if (sentenceCount >= 8 || buffer.length > 800) {
                     String subChunk = buffer.toString().trim();
                     if (subChunk.toLowerCase().contains(lowerQuery)) {
                        _addResult(searchResults, subChunk, localItemIndex, title, book, lowerQuery, i);
                     }
                     localItemIndex++; // ✅ Increment Local Index
                     buffer.clear();
                     sentenceCount = 0;
                   }
                }
                if (buffer.isNotEmpty) {
                  String subChunk = buffer.toString().trim();
                  if (subChunk.toLowerCase().contains(lowerQuery)) {
                     _addResult(searchResults, subChunk, localItemIndex, title, book, lowerQuery, i);
                  }
                  localItemIndex++; // ✅ Increment Local Index
                }
              }
            }
            currentGlobalOffset += paragraph.length + 2; 
          }
        }
      } catch (e) {
        debugPrint("Error searching book ${book.title}: $e");
      }
    }
    return searchResults;
  }
}

// Minimal class to support logic in this file
class RangeStyle {
  final int start;
  final int end;
  final bool isBold;
  RangeStyle({required this.start, required this.end, this.isBold = false});
}