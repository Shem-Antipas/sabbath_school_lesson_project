import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import '../models/book_meta.dart'; 
import 'egw_toc_screen.dart'; 
import 'egw_book_detail_screen.dart';

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

    // --- FIX: INTERCEPT BACK BUTTON ---
    return WillPopScope(
      onWillPop: () async {
        // If "Favorites" is open, the Back Button should just close Favorites
        // instead of closing the whole screen.
        if (showOnlyFavorites) {
          ref.read(showFavoritesOnlyProvider.notifier).state = false;
          return false; // Prevent the app from exiting this screen
        }
        return true; // Otherwise, let the app go back to the Dashboard
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(showOnlyFavorites ? "Favorite Books" : "Spirit of Prophecy"),
          centerTitle: true,
          backgroundColor: isDark ? null : const Color(0xFF06275C),
          foregroundColor: isDark ? null : Colors.white,
          
          // --- FIX: CUSTOM BACK BUTTON FOR FAVORITES ---
          leading: showOnlyFavorites
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // Turn off favorites mode
                    ref.read(showFavoritesOnlyProvider.notifier).state = false;
                  },
                )
              : null, // If null, Flutter uses the default back button (to Dashboard)
          
          actions: [
            // If viewing favorites, hide the bookmark filter button to avoid confusion, 
            // or keep it to toggle off. Keeping it is fine.
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
                          childAspectRatio: 0.7, // TALLER CARDS FOR BOOKS
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
            final int chapterIndex = result['chapterIndex'];
            final String chapterTitle = result['chapterTitle'];
            final String snippet = result['snippet'];

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
                // FIX: We DO NOT call close(context, null) here.
                // This keeps the search results in the history stack.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EGWBookDetailScreen(
                      bookMeta: book,
                      initialChapterIndex: chapterIndex,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EGWTableOfContentsScreen(bookMeta: book),
                      ),
                    );
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

  Future<List<Map<String, dynamic>>> _searchAllBooks(BuildContext context, String query) async {
    List<Map<String, dynamic>> searchResults = [];
    String lowerQuery = query.toLowerCase();

    for (var book in books) {
      try {
        final String response = await rootBundle.loadString(book.filePath);
        final Map<String, dynamic> data = json.decode(response);
        final List<dynamic> chapters = data['chapters'];

        for (int i = 0; i < chapters.length; i++) {
          String content = chapters[i]['content'] ?? "";
          String title = chapters[i]['title'] ?? "";

          if (content.toLowerCase().contains(lowerQuery)) {
            int matchIndex = content.toLowerCase().indexOf(lowerQuery);
            int start = (matchIndex - 20).clamp(0, content.length);
            int end = (matchIndex + 60).clamp(0, content.length);
            String snippet = "...${content.substring(start, end).replaceAll('\n', ' ')}...";

            searchResults.add({
              'book': book,
              'chapterIndex': i,
              'chapterTitle': title,
              'snippet': snippet,
            });
          }
        }
      } catch (e) {
        debugPrint("Error searching book ${book.title}: $e");
      }
    }
    return searchResults;
  }
}