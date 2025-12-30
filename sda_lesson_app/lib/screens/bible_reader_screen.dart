import 'package:flutter/material.dart';
import '../services/bible_api_service.dart';

class BibleReaderScreen extends StatefulWidget {
  final String chapterId;
  final String reference;

  const BibleReaderScreen({
    super.key,
    required this.chapterId,
    required this.reference,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final BibleApiService _api = BibleApiService();
  late Future<List<Map<String, String>>> _versesFuture;

  // UI Settings
  double _fontSize = 18.0;

  @override
  void initState() {
    super.initState();
    _versesFuture = _api.fetchChapterVerses(widget.chapterId);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get current theme colors (So it works for both Light & Dark modes)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.reference),
        centerTitle: false,
        backgroundColor: backgroundColor,
        // 2. Fix: Foreground color must contrast with background
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () {
              setState(() {
                _fontSize = _fontSize == 18.0 ? 22.0 : 18.0;
              });
            },
          ),
        ],
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
              child: Text("No content.", style: TextStyle(color: textColor)),
            );
          }

          final verses = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: _fontSize,
                  // 3. Fix: Use dynamic color (Black in Light mode, White in Dark mode)
                  color: textColor,
                  height: 1.6,
                  fontFamily: "Serif",
                ),
                children: verses.expand((verse) {
                  return [
                    // A. The Verse Number
                    WidgetSpan(
                      child: Transform.translate(
                        offset: const Offset(0, -4),
                        child: Text(
                          "${verse['number']} ",
                          style: TextStyle(
                            fontSize: _fontSize * 0.6,
                            color: Colors.grey, // Grey always looks okay
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // B. The Verse Text
                    TextSpan(text: "${verse['text']} "),
                  ];
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
