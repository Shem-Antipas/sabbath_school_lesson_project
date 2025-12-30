import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import 'egw_book_detail_screen.dart';
// Note: settings_screen.dart import removed as it is no longer used here

final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

class EGWLibraryScreen extends ConsumerWidget {
  const EGWLibraryScreen({super.key});

  final List<Map<String, dynamic>> egwBooks = const [
    {"title": "Steps to Christ", "code": "SC", "color": Colors.teal},
    {"title": "The Desire of Ages", "code": "DA", "color": Colors.redAccent},
    {"title": "The Great Controversy", "code": "GC", "color": Colors.brown},
    {"title": "Acts of the Apostles", "code": "AA", "color": Colors.blueGrey},
    {"title": "Patriarchs and Prophets", "code": "PP", "color": Colors.orange},
    {"title": "Prophets and Kings", "code": "PK", "color": Colors.green},
    {"title": "Ministry of Healing", "code": "MH", "color": Colors.cyan},
    {"title": "Education", "code": "Ed", "color": Colors.indigo},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final favorites = ref.watch(favoritesProvider);
    final showOnlyFavorites = ref.watch(showFavoritesOnlyProvider);

    final displayedBooks = showOnlyFavorites
        ? egwBooks.where((book) => favorites.contains(book['code'])).toList()
        : egwBooks;

    double width = MediaQuery.of(context).size.width;
    int columnCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(showOnlyFavorites ? "Favorite Books" : "EGW Library"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              showOnlyFavorites ? Icons.bookmark : Icons.bookmark_border,
            ),
            tooltip: "Filter Favorites",
            onPressed: () =>
                ref.read(showFavoritesOnlyProvider.notifier).state =
                    !showOnlyFavorites,
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
              delegate: EGWSearchDelegate(egwBooks),
            ),
          ),
          // SETTINGS ICON REMOVED FROM HERE
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: displayedBooks.isEmpty
              ? const Center(child: Text("No books to display here."))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    childAspectRatio: 0.8,
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
    );
  }

  Widget _buildBookTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> book,
    bool isDark,
  ) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorited = favorites.contains(book['code']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EGWBookDetailScreen(book: book),
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
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: book['color'],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        book['code'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        book['title'],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: IconButton(
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.red : Colors.white70,
              ),
              onPressed: () => ref
                  .read(favoritesProvider.notifier)
                  .toggleFavorite(book['code']),
            ),
          ),
        ],
      ),
    );
  }
}

class EGWSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> books;
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
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final results = books.where((book) {
      final input = query.toLowerCase();
      return book['title'].toLowerCase().contains(input) ||
          book['code'].toLowerCase().contains(input);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final book = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: book['color'],
            child: Text(
              book['code'],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(book['title']),
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EGWBookDetailScreen(book: book),
              ),
            );
          },
        );
      },
    );
  }
}
