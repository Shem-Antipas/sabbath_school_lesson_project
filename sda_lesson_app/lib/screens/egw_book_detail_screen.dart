import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_meta.dart';

// --- DATA MODELS ---
enum ItemType { header, content }

class BookItem {
  final ItemType type;
  final String text;
  final int chapterIndex; 

  BookItem({required this.type, required this.text, required this.chapterIndex});
}

class Chapter {
  final int number;
  final String title;
  final String content;

  Chapter({required this.number, required this.title, required this.content});
}

// --- HIGHLIGHT MODEL ---
class UserHighlight {
  final int itemIndex;
  final int startOffset;
  final int endOffset;
  final String colorHex; 

  UserHighlight({
    required this.itemIndex, 
    required this.startOffset, 
    required this.endOffset,
    this.colorHex = "0xFF81C784", // Default Green
  });

  Map<String, dynamic> toJson() => {
    'itemIndex': itemIndex,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'colorHex': colorHex,
  };

  factory UserHighlight.fromJson(Map<String, dynamic> json) => UserHighlight(
    itemIndex: json['itemIndex'],
    startOffset: json['startOffset'],
    endOffset: json['endOffset'],
    colorHex: json['colorHex'] ?? "0xFF81C784",
  );
}

// --- MAIN SCREEN ---
class EGWBookDetailScreen extends StatefulWidget {
  final BookMeta bookMeta;
  final int initialIndex; 
  final int initialChapterIndex; 
  final String? searchQuery;

  const EGWBookDetailScreen({
    super.key,
    required this.bookMeta,
    this.initialIndex = -1,        
    this.initialChapterIndex = -1, 
    this.searchQuery,
  });

  @override
  State<EGWBookDetailScreen> createState() => _EGWBookDetailScreenState();
}

class _EGWBookDetailScreenState extends State<EGWBookDetailScreen> {
  List<BookItem> _flatItems = [];
  List<Chapter> _rawChapters = [];
  bool _isLoading = true;
  
  // Highlighting State
  List<UserHighlight> _userHighlights = [];
  TextSelection? _currentSelection;
  int? _focusedItemIndex; 

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _loadAndProcessBook();
    _loadUserHighlights(); 
    _itemPositionsListener.itemPositions.addListener(_saveReadingProgress);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_saveReadingProgress);
    super.dispose();
  }

  // --- 1. PERSISTENCE LOGIC ---
  Future<void> _saveReadingProgress() async {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final firstVisible = positions
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce((min, position) => position.itemLeadingEdge < min.itemLeadingEdge ? position : min);

      int currentIndex = firstVisible.index;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_read_index_${widget.bookMeta.id}', currentIndex);
    }
  }

  Future<void> _loadUserHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('highlights_${widget.bookMeta.id}');
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _userHighlights = jsonList.map((j) => UserHighlight.fromJson(j)).toList();
      });
    }
  }

  Future<void> _addUserHighlight(int itemIndex, TextSelection selection) async {
    if (!selection.isValid || selection.isCollapsed) return;

    final newHighlight = UserHighlight(
      itemIndex: itemIndex,
      startOffset: selection.start,
      endOffset: selection.end,
      colorHex: "0xFF81C784", // Light Green
    );

    setState(() {
      _userHighlights.add(newHighlight);
      _currentSelection = null; 
    });

    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(_userHighlights.map((h) => h.toJson()).toList());
    await prefs.setString('highlights_${widget.bookMeta.id}', jsonString);
  }
  
  Future<void> _clearHighlightsForItem(int itemIndex) async {
    setState(() {
      _userHighlights.removeWhere((h) => h.itemIndex == itemIndex);
    });
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(_userHighlights.map((h) => h.toJson()).toList());
    await prefs.setString('highlights_${widget.bookMeta.id}', jsonString);
  }

  // --- 2. LOAD & PROCESS BOOK ---
  Future<void> _loadAndProcessBook() async {
    try {
      final String response = await rootBundle.loadString(widget.bookMeta.filePath);
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> chapterList = data['chapters'];

      List<BookItem> tempFlatItems = [];
      List<Chapter> tempChapters = [];

      for (int i = 0; i < chapterList.length; i++) {
        final c = chapterList[i];
        String title = c['title'];
        String content = c['content'];
        
        tempChapters.add(Chapter(number: c['chapter_number'], title: title, content: content));

        tempFlatItems.add(BookItem(type: ItemType.header, text: title, chapterIndex: i));

        RegExp splitRegex = RegExp(r'(?<=[.?!])\s+');
        List<String> rawSentences = content.split(splitRegex);
        StringBuffer buffer = StringBuffer();
        int sentenceCount = 0;

        for (String sentence in rawSentences) {
          if (sentence.trim().isEmpty) continue;
          buffer.write(sentence.trim());
          buffer.write(" "); 
          sentenceCount++;

          if (sentenceCount >= 6 || buffer.length > 800) {
            tempFlatItems.add(BookItem(
              type: ItemType.content, 
              text: buffer.toString().trim(), 
              chapterIndex: i
            ));
            buffer.clear();
            sentenceCount = 0;
          }
        }
        if (buffer.isNotEmpty) {
          tempFlatItems.add(BookItem(
            type: ItemType.content, 
            text: buffer.toString().trim(), 
            chapterIndex: i
          ));
        }
      }

      if (mounted) {
        setState(() {
          _rawChapters = tempChapters;
          _flatItems = tempFlatItems;
          _isLoading = false;
        });
        _handleInitialNavigation();
      }
    } catch (e) {
      debugPrint("Error processing book: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleInitialNavigation() async {
    int targetIndex = -1;

    if (widget.initialChapterIndex != -1) {
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          targetIndex = _flatItems.indexWhere((item) {
            return item.chapterIndex == widget.initialChapterIndex && 
                  item.text.toLowerCase().contains(widget.searchQuery!.toLowerCase());
          });
      }
      if (targetIndex == -1) {
          targetIndex = _flatItems.indexWhere(
            (item) => item.chapterIndex == widget.initialChapterIndex && item.type == ItemType.header
          );
      }
    }
    else if (widget.initialIndex != -1) {
      targetIndex = widget.initialIndex;
    }
    else {
      final prefs = await SharedPreferences.getInstance();
      targetIndex = prefs.getInt('last_read_index_${widget.bookMeta.id}') ?? 0;
      if (targetIndex > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resuming where you left off..."), duration: Duration(milliseconds: 1500)),
        );
      }
    }

    if (targetIndex <= 0) targetIndex = 0;

    if (targetIndex > 0 && targetIndex < _flatItems.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: targetIndex, alignment: 0.0); 
        }
      });
    }
  }

  void _jumpToChapter(int chapterIndex) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    int index = _flatItems.indexWhere((item) => item.chapterIndex == chapterIndex && item.type == ItemType.header);
    if (index != -1) {
      _itemScrollController.jumpTo(index: index, alignment: 0.0);
    }
  }

  List<TextSpan> _buildComplexText(BuildContext context, int itemIndex, String text, String? query, bool isHeader) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color textColor = isHeader 
      ? (isDark ? Colors.white70 : const Color(0xFF06275C))
      : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);
      
    final TextStyle baseStyle = isHeader 
      ? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia', height: 1.3)
      : const TextStyle(fontSize: 18, height: 1.8, fontFamily: 'Georgia');

    List<_RangeStyle> ranges = [];

    if (query != null && query.isNotEmpty) {
      String lowerText = text.toLowerCase();
      String lowerQuery = query.toLowerCase();
      int matchIndex = lowerText.indexOf(lowerQuery);
      while (matchIndex != -1) {
        ranges.add(_RangeStyle(
          start: matchIndex, 
          end: matchIndex + lowerQuery.length, 
          color: Colors.yellow,
          textColor: Colors.black
        ));
        matchIndex = lowerText.indexOf(lowerQuery, matchIndex + lowerQuery.length);
      }
    }

    final myHighlights = _userHighlights.where((h) => h.itemIndex == itemIndex);
    for (var h in myHighlights) {
      int safeStart = h.startOffset.clamp(0, text.length);
      int safeEnd = h.endOffset.clamp(0, text.length);
      if (safeStart < safeEnd) {
        ranges.add(_RangeStyle(
          start: safeStart, 
          end: safeEnd, 
          color: Color(int.parse(h.colorHex)),
          textColor: Colors.black 
        ));
      }
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));

    List<TextSpan> spans = [];
    int cursor = 0;

    for (var range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start), style: baseStyle.copyWith(color: textColor)));
      }

      int end = range.end > text.length ? text.length : range.end;
      if (end > cursor) { 
         int start = range.start < cursor ? cursor : range.start;
         
         spans.add(TextSpan(
           text: text.substring(start, end),
           style: baseStyle.copyWith(
             backgroundColor: range.color,
             color: range.textColor, 
           )
         ));
         cursor = end;
      }
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle.copyWith(color: textColor)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.grey[900] : const Color(0xFF06275C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookMeta.title),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_flatItems.isNotEmpty) {
                showSearch(
                  context: context,
                  delegate: GlobalBookSearchDelegate(flatItems: _flatItems, bookMeta: widget.bookMeta),
                );
              }
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_book),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            // --- UPDATED DRAWER HEADER ---
            DrawerHeader(
              decoration: BoxDecoration(
                color: appBarColor, // Fallback
                image: DecorationImage(
                  image: AssetImage(widget.bookMeta.coverImage), // Show book cover
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6), // Darken image by 60% for readability
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  widget.bookMeta.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 20, // Slightly larger
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 2))
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ListView.builder(
                  itemCount: _rawChapters.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_rawChapters[index].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _jumpToChapter(index),
                    );
                  },
                ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              itemCount: _flatItems.length,
              itemBuilder: (context, index) {
                final item = _flatItems[index];
                
                return Padding(
                  padding: item.type == ItemType.header 
                      ? const EdgeInsets.fromLTRB(20, 40, 20, 20)
                      : const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildComplexText(context, index, item.text, widget.searchQuery, item.type == ItemType.header)
                    ),
                    textAlign: item.type == ItemType.header ? TextAlign.center : TextAlign.justify,
                    
                    onSelectionChanged: (selection, cause) {
                      _currentSelection = selection;
                      _focusedItemIndex = index;
                    },
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar(
                        anchors: editableTextState.contextMenuAnchors,
                        children: [
                          TextSelectionToolbarTextButton(
                            padding: const EdgeInsets.all(8.0),
                            onPressed: () {
                              editableTextState.copySelection(SelectionChangedCause.toolbar);
                            },
                            child: const Text('Copy'),
                          ),
                          TextSelectionToolbarTextButton(
                            padding: const EdgeInsets.all(8.0),
                            onPressed: () {
                              if (_currentSelection != null && _focusedItemIndex == index) {
                                _addUserHighlight(index, _currentSelection!);
                                editableTextState.hideToolbar();
                              }
                            },
                            child: const Text('Highlight', style: TextStyle(color: Colors.green)),
                          ),
                          if (_userHighlights.any((h) => h.itemIndex == index))
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(8.0),
                              onPressed: () {
                                _clearHighlightsForItem(index);
                                editableTextState.hideToolbar();
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- HELPER CLASS ---
class _RangeStyle {
  final int start;
  final int end;
  final Color color;
  final Color textColor;
  _RangeStyle({required this.start, required this.end, required this.color, required this.textColor});
}

// --- SEARCH DELEGATE ---
class GlobalBookSearchDelegate extends SearchDelegate {
  final List<BookItem> flatItems;
  final BookMeta bookMeta;

  GlobalBookSearchDelegate({required this.flatItems, required this.bookMeta});

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
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text("Search inside this book..."));

    final results = flatItems.where((item) {
      return item.text.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          title: Text(item.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text("Chapter ${item.chapterIndex + 1}"),
          onTap: () {
            int originalIndex = flatItems.indexOf(item);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EGWBookDetailScreen(
                  bookMeta: bookMeta,
                  initialIndex: originalIndex,
                  searchQuery: query,
                ),
              ),
            );
          },
        );
      },
    );
  }
}