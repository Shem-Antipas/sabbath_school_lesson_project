import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bible_api_service.dart';
import 'bible_reader_screen.dart';

class BibleVerseScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  final String chapterId;
  final String chapterNumber;

  const BibleVerseScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.chapterId,
    required this.chapterNumber,
  });

  @override
  ConsumerState<BibleVerseScreen> createState() => _BibleVerseScreenState();
}

class _BibleVerseScreenState extends ConsumerState<BibleVerseScreen> {
  final BibleApiService _api = BibleApiService();
  late Future<List<Map<String, String>>> _versesFuture;

  @override
  void initState() {
    super.initState();
    _versesFuture = _api.fetchChapterVerses(widget.chapterId);
  }

  @override
  Widget build(BuildContext context) {
    // 1. THEME DETECTION
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. DYNAMIC COLORS
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFFBFBFD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // FIX: Use White for text in Dark Mode, Brand Red for Light Mode
    final accentColor = isDark ? Colors.white : const Color(0xFF7D2D3B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "${widget.bookName} ${widget.chapterNumber}",
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: textColor),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No verses found.",
                style: TextStyle(color: textColor),
              ),
            );
          }

          final verses = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select a Verse",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: verses.length,
                  itemBuilder: (context, index) {
                    final verseNumber =
                        verses[index]['number'] ?? "${index + 1}";

                    return InkWell(
                      onTap: () {
                        // Parse verse number safely
                        int verseNum = int.tryParse(verseNumber) ?? 1;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BibleReaderScreen(
                              chapterId: widget.chapterId,
                              reference:
                                  "${widget.bookName} ${widget.chapterNumber}",
                              targetVerse: verseNum, // Pass verse for scrolling
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
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            verseNumber,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor, // <--- Fixed Color Here
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
