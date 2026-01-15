import 'dart:async';
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
  final List<RangeStyle> boldRanges; 

  BookItem({
    required this.type, 
    required this.text, 
    required this.chapterIndex,
    this.boldRanges = const [],
  });
}

class Chapter {
  final int number;
  final String title;
  final String content;

  Chapter({required this.number, required this.title, required this.content});
}

class UserHighlight {
  final int itemIndex;
  final int startOffset;
  final int endOffset;
  final String colorHex;

  UserHighlight({
    required this.itemIndex,
    required this.startOffset,
    required this.endOffset,
    required this.colorHex,
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

class RangeStyle {
  final int start;
  final int end;
  final bool isBold;
  final Color? backgroundColor;

  RangeStyle({required this.start, required this.end, this.isBold = false, this.backgroundColor});
}

// --- MAIN SCREEN ---
class EGWBookDetailScreen extends StatefulWidget {
  final BookMeta bookMeta;
  final int initialIndex; // Exact paragraph index (for Search)
  final int initialChapterIndex; // Chapter start index (for TOC)
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

  Future<void> _addUserHighlight(int itemIndex, TextSelection selection, String colorHex) async {
    if (!selection.isValid || selection.isCollapsed) return;
    _userHighlights.removeWhere((h) =>
        h.itemIndex == itemIndex &&
        h.startOffset < selection.end &&
        h.endOffset > selection.start);

    final newHighlight = UserHighlight(
      itemIndex: itemIndex,
      startOffset: selection.start,
      endOffset: selection.end,
      colorHex: colorHex,
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
        String before = remaining.substring(0, match.start);
        cleanBuffer.write(before);
        
        String boldContent = match.group(1) ?? "";
        int start = cleanBuffer.length;
        cleanBuffer.write(boldContent);
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
        String rawContent = c['content'];

        tempChapters.add(Chapter(number: c['chapter_number'], title: title, content: rawContent));

        // Add Header
        tempFlatItems.add(BookItem(
          type: ItemType.header, 
          text: title.replaceAll(RegExp(r'<[^>]*>'), ''), 
          chapterIndex: i
        ));

        // Process Content
        var parsed = _parseHtmlContent(rawContent);
        String fullCleanText = parsed['text'];
        List<RangeStyle> fullBoldRanges = parsed['boldRanges'];

        List<String> hardParagraphs = fullCleanText.split('\n\n');
        int currentGlobalOffset = 0;

        for (String paragraph in hardParagraphs) {
          if (paragraph.trim().isEmpty) {
            currentGlobalOffset += paragraph.length + 2; 
            continue;
          }

          int paraStart = currentGlobalOffset;
          int paraEnd = paraStart + paragraph.length;

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

          List<String> finalSubChunks = [];
          for (String chunk in boldSplitChunks) {
            if (chunk.isEmpty) continue;

            RegExp sentenceSplit = RegExp(r'(?<=[.?!])\s+');
            List<String> sentences = chunk.split(sentenceSplit);
            
            if (sentences.length <= 8) {
              finalSubChunks.add(chunk);
            } else {
              StringBuffer buffer = StringBuffer();
              int sentenceCount = 0;
              for (String s in sentences) {
                 buffer.write(s.trim());
                 buffer.write(" "); 
                 sentenceCount++;
                 
                 if (sentenceCount >= 8 || buffer.length > 800) {
                   finalSubChunks.add(buffer.toString().trim());
                   buffer.clear();
                   sentenceCount = 0;
                 }
              }
              if (buffer.isNotEmpty) {
                finalSubChunks.add(buffer.toString().trim());
              }
            }
          }

          for (String chunkText in finalSubChunks) {
            int chunkStart = currentGlobalOffset;
            int chunkEnd = chunkStart + chunkText.length;
            
            List<RangeStyle> chunkBoldRanges = [];
            for (var r in fullBoldRanges) {
              if (r.start < chunkEnd && r.end > chunkStart) {
                int relativeStart = (r.start > chunkStart ? r.start : chunkStart) - chunkStart;
                int relativeEnd = (r.end < chunkEnd ? r.end : chunkEnd) - chunkStart;
                chunkBoldRanges.add(RangeStyle(start: relativeStart, end: relativeEnd, isBold: true));
              }
            }

            tempFlatItems.add(BookItem(
              type: ItemType.content,
              text: chunkText.trim(),
              chapterIndex: i,
              boldRanges: chunkBoldRanges,
            ));
            
            int nextSearch = fullCleanText.indexOf(chunkText, currentGlobalOffset);
            if (nextSearch != -1) {
              currentGlobalOffset = nextSearch + chunkText.length;
              if (currentGlobalOffset < fullCleanText.length) currentGlobalOffset++; 
            } else {
              currentGlobalOffset += chunkText.length + 1;
            }
          }
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

    // A. Direct Item Index (Exact Search Result)
    if (widget.initialIndex != -1) {
      targetIndex = widget.initialIndex;
    } 
    // B. Chapter Index (Navigation from TOC)
    else if (widget.initialChapterIndex != -1) {
      targetIndex = _flatItems.indexWhere((item) => 
        item.chapterIndex == widget.initialChapterIndex && item.type == ItemType.header
      );
    } 
    // C. Resume Reading
    else {
      final prefs = await SharedPreferences.getInstance();
      targetIndex = prefs.getInt('last_read_index_${widget.bookMeta.id}') ?? 0;
    }

    if (targetIndex >= 0 && targetIndex < _flatItems.length) {
      _scrollToIndex(targetIndex);
    }
  }

  // --- FIX: ALIGNMENT SET TO 0.0 TO HIDE PREVIOUS CHAPTER ---
  void _scrollToIndex(int index) {
    const double alignment = 0.0; // Snap to very top

    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: index, alignment: alignment);
    } else {
      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: index, alignment: alignment);
          timer.cancel();
        } else if (timer.tick > 20) {
          timer.cancel();
        }
      });
    }
  }

  void _jumpToChapter(int chapterIndex) {
    if (Navigator.canPop(context)) Navigator.pop(context);

    int index = _flatItems.indexWhere((item) => 
      item.chapterIndex == chapterIndex && item.type == ItemType.header
    );

    if (index != -1) {
      _scrollToIndex(index);
    }
  }

  List<TextSpan> _buildComplexText(BuildContext context, int itemIndex, BookItem item, String? query) {
    final String text = item.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeader = item.type == ItemType.header;

    final Color textColor = isHeader
        ? (isDark ? Colors.white : const Color(0xFF06275C))
        : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);

    final TextStyle baseStyle = isHeader
        ? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia', height: 1.3)
        : const TextStyle(fontSize: 18, height: 1.8, fontFamily: 'Georgia');

    List<Map<String, dynamic>> charStyles = List.generate(text.length, (index) => {
      'isBold': false,
      'bgColor': null,
    });

    for (var r in item.boldRanges) {
      for (int i = r.start; i < r.end && i < text.length; i++) {
        charStyles[i]['isBold'] = true;
      }
    }

    final myHighlights = _userHighlights.where((h) => h.itemIndex == itemIndex);
    for (var h in myHighlights) {
      int safeStart = h.startOffset.clamp(0, text.length);
      int safeEnd = h.endOffset.clamp(0, text.length);
      for (int i = safeStart; i < safeEnd; i++) {
        charStyles[i]['bgColor'] = Color(int.parse(h.colorHex));
      }
    }

    if (query != null && query.isNotEmpty) {
      String lowerText = text.toLowerCase();
      String lowerQuery = query.toLowerCase();
      int matchIndex = lowerText.indexOf(lowerQuery);
      while (matchIndex != -1) {
        for (int i = matchIndex; i < matchIndex + lowerQuery.length && i < text.length; i++) {
          charStyles[i]['bgColor'] = Colors.yellow; 
        }
        matchIndex = lowerText.indexOf(lowerQuery, matchIndex + lowerQuery.length);
      }
    }

    List<TextSpan> spans = [];
    if (text.isEmpty) return spans;

    int currentStart = 0;
    var currentStyle = charStyles[0];

    for (int i = 1; i < text.length; i++) {
      var style = charStyles[i];
      if (style['isBold'] != currentStyle['isBold'] || style['bgColor'] != currentStyle['bgColor']) {
        spans.add(TextSpan(
          text: text.substring(currentStart, i),
          style: baseStyle.copyWith(
            color: textColor,
            fontWeight: (currentStyle['isBold'] as bool) ? FontWeight.bold : FontWeight.normal,
            backgroundColor: currentStyle['bgColor'] as Color?,
          ),
        ));
        currentStart = i;
        currentStyle = style;
      }
    }
    spans.add(TextSpan(
      text: text.substring(currentStart),
      style: baseStyle.copyWith(
        color: textColor,
        fontWeight: (currentStyle['isBold'] as bool) ? FontWeight.bold : FontWeight.normal,
        backgroundColor: currentStyle['bgColor'] as Color?,
      ),
    ));

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
            DrawerHeader(
              decoration: BoxDecoration(
                color: appBarColor,
                image: DecorationImage(
                  image: AssetImage(widget.bookMeta.coverImage),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  widget.bookMeta.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _rawChapters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_rawChapters[index].title, maxLines: 1),
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
                      children: _buildComplexText(context, index, item, widget.searchQuery),
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
                            padding: const EdgeInsets.all(12.0),
                            onPressed: () {
                              editableTextState.copySelection(SelectionChangedCause.toolbar);
                            },
                            child: const Icon(Icons.copy, size: 20),
                          ),
                          _buildColorButton(index, "0xFF81C784", Colors.green, editableTextState), 
                          _buildColorButton(index, "0xFFFFF59D", Colors.yellow, editableTextState), 
                          _buildColorButton(index, "0xFF64B5F6", Colors.blue, editableTextState), 
                          _buildColorButton(index, "0xFFF06292", Colors.pink, editableTextState), 
                          TextSelectionToolbarTextButton(
                            padding: const EdgeInsets.all(12.0),
                            onPressed: () {
                              _clearHighlightsForItem(index);
                              editableTextState.hideToolbar();
                            },
                            child: const Icon(Icons.format_clear, size: 20, color: Colors.red),
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

  Widget _buildColorButton(int index, String hex, Color color, EditableTextState state) {
    return InkWell(
      onTap: () {
        if (_currentSelection != null && _focusedItemIndex == index) {
          _addUserHighlight(index, _currentSelection!, hex);
          state.hideToolbar();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
      ),
    );
  }
}

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
          title: Text(
            item.text, 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis
          ),
          subtitle: Text("Chapter ${item.chapterIndex + 1}"),
          onTap: () {
            // PASS THE EXACT ITEM INDEX
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