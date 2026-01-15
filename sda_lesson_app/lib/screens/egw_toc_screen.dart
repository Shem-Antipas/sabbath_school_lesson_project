import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book_meta.dart';
import 'egw_book_detail_screen.dart';

class EGWTableOfContentsScreen extends StatefulWidget {
  final BookMeta bookMeta;

  const EGWTableOfContentsScreen({super.key, required this.bookMeta});

  @override
  State<EGWTableOfContentsScreen> createState() => _EGWTableOfContentsScreenState();
}

class _EGWTableOfContentsScreenState extends State<EGWTableOfContentsScreen> {
  List<dynamic> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final String response = await rootBundle.loadString(widget.bookMeta.filePath);
      final Map<String, dynamic> data = json.decode(response);
      
      setState(() {
        _chapters = data['chapters'];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading TOC: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final appBarColor = isDark ? Colors.grey[900] : const Color(0xFF06275C);
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white70 : Colors.grey;
    final avatarBgColor = isDark ? Colors.grey[800] : const Color(0xFF06275C).withOpacity(0.1);
    final avatarTextColor = isDark ? Colors.white : const Color(0xFF06275C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookMeta.title),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Search in this book",
            onPressed: () {
              if (!_isLoading && _chapters.isNotEmpty) {
                showSearch(
                  context: context,
                  delegate: EGWBookSearchDelegate(
                    bookMeta: widget.bookMeta, 
                    chapters: _chapters
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      leading: CircleAvatar(
                        backgroundColor: avatarBgColor,
                        child: Text(
                          "${chapter['chapter_number']}",
                          style: TextStyle(
                            color: avatarTextColor, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      title: Text(
                        chapter['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor, 
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: iconColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EGWBookDetailScreen(
                              bookMeta: widget.bookMeta,
                              initialChapterIndex: index,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 70, color: isDark ? Colors.grey[800] : Colors.grey[300]), 
                  ],
                );
              },
            ),
    );
  }
}

// --- SEARCH DELEGATE ---
class EGWBookSearchDelegate extends SearchDelegate {
  final BookMeta bookMeta;
  final List<dynamic> chapters;

  EGWBookSearchDelegate({required this.bookMeta, required this.chapters});

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
    if (query.isEmpty) {
      return const Center(child: Text("Search inside this book..."));
    }

    final lowerQuery = query.toLowerCase();
    List<Map<String, dynamic>> results = [];

    // --- EXACT INDEX MATCHING LOGIC ---
    // We must mimic exactly how EGWBookDetailScreen breaks down items.
    // 1. Header
    // 2. Paragraphs split by \n\n
    // 3. Chunks split by Bold Tags
    // 4. Chunks split by Sentence Count (8 sentences rule)
    
    int globalItemIndex = 0;

    for (var chapter in chapters) {
      // 1. Header (counts as 1 item)
      globalItemIndex++;

      // Parsing Logic (Copied from Detail Screen)
      String rawContent = chapter['content'] ?? "";
      
      // Parse HTML to get ranges
      var parsed = _parseHtmlContent(rawContent);
      String fullCleanText = parsed['text'];
      List<RangeStyle> fullBoldRanges = parsed['boldRanges'];

      // Split paragraphs
      List<String> hardParagraphs = fullCleanText.split('\n\n');
      int currentGlobalOffset = 0;

      for (String paragraph in hardParagraphs) {
        if (paragraph.trim().isEmpty) {
          currentGlobalOffset += paragraph.length + 2; 
          continue;
        }

        int paraStart = currentGlobalOffset;
        int paraEnd = paraStart + paragraph.length;

        // --- STEP A: DETECT BOLD SPLITS ---
        List<int> splitPoints = [];
        for (var r in fullBoldRanges) {
          if (r.start > paraStart && r.start < paraEnd) {
            splitPoints.add(r.start - paraStart);
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

        // --- STEP B: SENTENCE SPLITTING ---
        for (String chunk in boldSplitChunks) {
          if (chunk.isEmpty) continue;

          RegExp sentenceSplit = RegExp(r'(?<=[.?!])\s+');
          List<String> sentences = chunk.split(sentenceSplit);
          
          if (sentences.length <= 8) {
            // This is one item
            _checkAndAddResult(results, chunk, globalItemIndex, chapter['title'], lowerQuery);
            globalItemIndex++;
          } else {
             // Chop it up
             StringBuffer buffer = StringBuffer();
             int sentenceCount = 0;
             for (String s in sentences) {
                 buffer.write(s.trim());
                 buffer.write(" "); 
                 sentenceCount++;
                 
                 if (sentenceCount >= 8 || buffer.length > 800) {
                   String subChunk = buffer.toString().trim();
                   _checkAndAddResult(results, subChunk, globalItemIndex, chapter['title'], lowerQuery);
                   globalItemIndex++;
                   
                   buffer.clear();
                   sentenceCount = 0;
                 }
             }
             if (buffer.isNotEmpty) {
               String subChunk = buffer.toString().trim();
               _checkAndAddResult(results, subChunk, globalItemIndex, chapter['title'], lowerQuery);
               globalItemIndex++;
             }
          }
        }
        currentGlobalOffset += paragraph.length + 2; 
      }
    }

    if (results.isEmpty) {
      return const Center(child: Text("No matches found."));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return ListTile(
          title: Text(result['chapterTitle'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(result['snippet']),
          onTap: () {
            // Pass the PRECISE calculated index
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EGWBookDetailScreen(
                  bookMeta: bookMeta,
                  initialIndex: result['initialIndex'], 
                  searchQuery: query,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _checkAndAddResult(
    List<Map<String, dynamic>> results, 
    String text, 
    int index, 
    String title, 
    String lowerQuery
  ) {
    if (text.toLowerCase().contains(lowerQuery)) {
      int matchIndex = text.toLowerCase().indexOf(lowerQuery);
      int start = (matchIndex - 20).clamp(0, text.length);
      int end = (matchIndex + 60).clamp(0, text.length);
      String snippet = "...${text.substring(start, end).replaceAll('\n', ' ')}...";

      results.add({
        'initialIndex': index, 
        'chapterTitle': title,
        'snippet': snippet,
      });
    }
  }

  // Helper needed for Bold Logic (Same as Detail Screen)
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
}

// Needed to avoid errors in this file, even though it's defined in the detail screen file
class RangeStyle {
  final int start;
  final int end;
  final bool isBold;
  final Color? backgroundColor;

  RangeStyle({required this.start, required this.end, this.isBold = false, this.backgroundColor});
}