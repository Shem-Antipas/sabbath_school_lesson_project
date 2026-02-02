import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/devotional_provider.dart';
import 'devotional_daily_list_screen.dart';
import '../utils/global_devotional_search.dart';

class DevotionalsLibraryScreen extends StatelessWidget {
  const DevotionalsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFBFBFD);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Devotionals Library",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textColor),
            onPressed: () {
              showSearch(
                context: context,
                delegate: GlobalDevotionalSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, 
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: availableDevotionals.length,
        itemBuilder: (context, index) {
          final book = availableDevotionals[index];
          return _buildBookCard(context, book, isDark);
        },
      ),
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    DevotionalBookInfo book,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonthSelectionScreen(book: book),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), 
              blurRadius: 8,
              offset: const Offset(0, 4), 
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. IMAGE SECTION
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.asset(
                  book.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF5D4037),
                      child: const Center(
                        child: Icon(
                          Icons.menu_book,
                          size: 40,
                          color: Colors.white24,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. TITLE SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SCREEN 2: MONTH SELECTION
// -----------------------------------------------------------------------------
class MonthSelectionScreen extends StatelessWidget {
  final DevotionalBookInfo book;

  final List<String> months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  const MonthSelectionScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(book.title, style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        separatorBuilder: (c, i) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              months[index],
              style: TextStyle(fontSize: 18, color: textColor),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DevotionalDailyListScreen(
                    bookId: book.id,
                    bookTitle: book.title,
                    coverImagePath: book.imagePath, // ✅ PASSED IMAGE PATH HERE
                    monthIndex: index + 1,
                    monthName: months[index],
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