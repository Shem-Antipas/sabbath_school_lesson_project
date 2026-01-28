import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_meta.dart';

// --- DATA MODELS ---
enum ItemType { header, content, navigation }

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
  final int chapterIndex; 
  final int itemIndex;
  final int startOffset;
  final int endOffset;
  final String colorHex;

  UserHighlight({
    required this.chapterIndex,
    required this.itemIndex,
    required this.startOffset,
    required this.endOffset,
    required this.colorHex,
  });

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'itemIndex': itemIndex,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'colorHex': colorHex,
  };

  factory UserHighlight.fromJson(Map<String, dynamic> json) => UserHighlight(
    chapterIndex: json['chapterIndex'] ?? 0,
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
  final int initialChapterIndex; 
  final String? searchQuery;
  final int initialIndex; 

  const EGWBookDetailScreen({
    super.key,
    required this.bookMeta,
    this.initialChapterIndex = 0,
    this.searchQuery,
    this.initialIndex = 0,
  });

  @override
  State<EGWBookDetailScreen> createState() => _EGWBookDetailScreenState();
}

class _EGWBookDetailScreenState extends State<EGWBookDetailScreen> {
  // Current View Data
  List<BookItem> _currentViewItems = [];
  List<Chapter> _allChapters = [];
  
  bool _isLoading = true;
  int _currentChapterIndex = 0;
  double _chapterProgress = 0.0;
  
  // Settings
  double _fontSize = 18.0; 

  List<UserHighlight> _userHighlights = [];
  TextSelection? _currentSelection;
  int? _focusedItemIndex;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    
    if (widget.initialChapterIndex > 0) {
      _currentChapterIndex = widget.initialChapterIndex;
    } else {
      _currentChapterIndex = 0; 
    }

    _loadBookData();
    _loadUserHighlights();
    _itemPositionsListener.itemPositions.addListener(_onScrollUpdate);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScrollUpdate);
    super.dispose();
  }

  void _onScrollUpdate() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _currentViewItems.isEmpty) return;

    final firstVisible = positions
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .reduce((min, position) => position.itemLeadingEdge < min.itemLeadingEdge ? position : min);

    int currentIndex = firstVisible.index;
    int totalItems = _currentViewItems.length;

    double localProgress = 0.0;
    if (totalItems > 0) {
      localProgress = currentIndex / totalItems;
    }

    if (localProgress != _chapterProgress) {
      setState(() {
        _chapterProgress = localProgress.clamp(0.0, 1.0);
      });
    }
    
    // ✅ SAVING HISTORY AUTOMATICALLY ON SCROLL
    _saveLastReadPosition(currentIndex);
  }

  Future<void> _saveLastReadPosition(int scrollIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_chapter_${widget.bookMeta.id}', _currentChapterIndex);
    await prefs.setInt('last_read_scroll_${widget.bookMeta.id}', scrollIndex);
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
    
    // Remove existing overlaps
    _userHighlights.removeWhere((h) =>
        h.chapterIndex == _currentChapterIndex &&
        h.itemIndex == itemIndex &&
        h.startOffset < selection.end &&
        h.endOffset > selection.start);

    final newHighlight = UserHighlight(
      chapterIndex: _currentChapterIndex,
      itemIndex: itemIndex,
      startOffset: selection.start,
      endOffset: selection.end,
      colorHex: colorHex,
    );

    setState(() {
      _userHighlights.add(newHighlight);
      _currentSelection = null;
    });

    // ✅ SAVE TO PERSISTENT STORAGE
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(_userHighlights.map((h) => h.toJson()).toList());
    await prefs.setString('highlights_${widget.bookMeta.id}', jsonString);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Highlight saved!"), duration: Duration(milliseconds: 800)),
      );
    }
  }

  Future<void> _clearHighlightsForItem(int itemIndex) async {
    setState(() {
      _userHighlights.removeWhere((h) => h.itemIndex == itemIndex && h.chapterIndex == _currentChapterIndex);
    });
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(_userHighlights.map((h) => h.toJson()).toList());
    await prefs.setString('highlights_${widget.bookMeta.id}', jsonString);
  }

  // --- PARSING ---
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

  Future<void> _loadBookData() async {
    try {
      final String response = await rootBundle.loadString(widget.bookMeta.filePath);
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> chapterList = data['chapters'];

      List<Chapter> tempChapters = [];
      for (int i = 0; i < chapterList.length; i++) {
        final c = chapterList[i];
        tempChapters.add(Chapter(
          number: c['chapter_number'] ?? i + 1, 
          title: c['title'], 
          content: c['content']
        ));
      }

      _allChapters = tempChapters;

      if (widget.initialChapterIndex == 0 && widget.initialIndex == 0) {
        final prefs = await SharedPreferences.getInstance();
        _currentChapterIndex = prefs.getInt('last_read_chapter_${widget.bookMeta.id}') ?? 0;
      }

      await _loadChapterIntoView(_currentChapterIndex, resetScroll: widget.initialIndex == 0);

      if (widget.initialIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(widget.initialIndex);
        });
      }

    } catch (e) {
      debugPrint("Error loading book: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChapterIntoView(int chapterIndex, {bool resetScroll = true}) async {
    setState(() => _isLoading = true);

    if (chapterIndex < 0 || chapterIndex >= _allChapters.length) {
      setState(() => _isLoading = false);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 50)); 

    final Chapter c = _allChapters[chapterIndex];
    List<BookItem> tempItems = [];

    // Header
    tempItems.add(BookItem(
      type: ItemType.header, 
      text: c.title.replaceAll(RegExp(r'<[^>]*>'), ''), 
      chapterIndex: chapterIndex
    ));

    // Content Parsing
    var parsed = _parseHtmlContent(c.content);
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

      for (String chunk in boldSplitChunks) {
        if (chunk.isEmpty) continue;

        RegExp sentenceSplit = RegExp(r'(?<=[.?!])\s+');
        List<String> sentences = chunk.split(sentenceSplit);
        
        if (sentences.length <= 8) {
          _addContentItem(tempItems, chunk, chapterIndex, fullBoldRanges, currentGlobalOffset);
        } else {
          StringBuffer buffer = StringBuffer();
          int sentenceCount = 0;
          for (String s in sentences) {
             buffer.write(s.trim());
             buffer.write(" "); 
             sentenceCount++;
             
             if (sentenceCount >= 8 || buffer.length > 800) {
               _addContentItem(tempItems, buffer.toString().trim(), chapterIndex, fullBoldRanges, currentGlobalOffset);
               buffer.clear();
               sentenceCount = 0;
             }
          }
          if (buffer.isNotEmpty) {
            _addContentItem(tempItems, buffer.toString().trim(), chapterIndex, fullBoldRanges, currentGlobalOffset);
          }
        }
      }
      currentGlobalOffset += paragraph.length + 2;
    }

    // Navigation Item
    tempItems.add(BookItem(
      type: ItemType.navigation,
      text: "",
      chapterIndex: chapterIndex
    ));

    if (mounted) {
      setState(() {
        _currentViewItems = tempItems;
        _currentChapterIndex = chapterIndex;
        _isLoading = false;
        _chapterProgress = 0.0;
      });

      if (resetScroll) {
        if (_itemScrollController.isAttached) _itemScrollController.jumpTo(index: 0);
      } else {
        final prefs = await SharedPreferences.getInstance();
        int savedScroll = prefs.getInt('last_read_scroll_${widget.bookMeta.id}') ?? 0;
        if (_itemScrollController.isAttached) _itemScrollController.jumpTo(index: savedScroll);
      }
    }
  }

  void _addContentItem(List<BookItem> items, String text, int chapterIndex, List<RangeStyle> fullBoldRanges, int globalOffset) {
    if (text.isEmpty) return;
    List<RangeStyle> chunkBoldRanges = [];
    items.add(BookItem(
      type: ItemType.content,
      text: text,
      chapterIndex: chapterIndex,
      boldRanges: chunkBoldRanges, 
    ));
  }

  void _navigateToChapter(int index) {
    if (index >= 0 && index < _allChapters.length) {
      _loadChapterIntoView(index);
    }
  }

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: index);
    } else {
      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) { timer.cancel(); return; }
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: index);
          timer.cancel();
        } else if (timer.tick > 20) {
          timer.cancel();
        }
      });
    }
  }

  // --- RENDERING TEXT ---
  List<TextSpan> _buildComplexText(BuildContext context, int itemIndex, BookItem item, String? query) {
    final String text = item.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeader = item.type == ItemType.header;

    final Color textColor = isHeader
        ? (isDark ? Colors.white : const Color(0xFF06275C))
        : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);

    final TextStyle baseStyle = isHeader
        ? TextStyle(fontSize: _fontSize + 6, fontWeight: FontWeight.bold, fontFamily: 'Georgia', height: 1.3)
        : TextStyle(fontSize: _fontSize, height: 1.8, fontFamily: 'Georgia');

    List<Map<String, dynamic>> charStyles = List.generate(text.length, (index) => {
      'isBold': false,
      'bgColor': null,
    });

    for (var r in item.boldRanges) {
      for (int i = r.start; i < r.end && i < text.length; i++) {
        charStyles[i]['isBold'] = true;
      }
    }

    final myHighlights = _userHighlights.where((h) => h.chapterIndex == _currentChapterIndex && h.itemIndex == itemIndex);
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

  // --- UX: FONT SIZE SETTINGS ---
  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // ✅ StatefulBuilder ensures slider updates visibly
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Display Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 20),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12.0,
                          max: 30.0,
                          divisions: 9,
                          label: _fontSize.round().toString(),
                          onChanged: (val) {
                            setModalState(() => _fontSize = val); // Updates Slider
                            setState(() => _fontSize = val);      // Updates Text
                          }, 
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 30),
                    ],
                  ),
                  const Center(child: Text("Drag to adjust text size", style: TextStyle(color: Colors.grey))),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appBarColor = isDark ? Colors.grey[900] : const Color(0xFF06275C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookMeta.title),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.format_size), 
            tooltip: "Text Size",
            onPressed: _showDisplaySettings,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.list),
              tooltip: "Chapters",
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
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
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
                itemCount: _allChapters.length,
                itemBuilder: (context, index) {
                  bool isActive = index == _currentChapterIndex;
                  return Container(
                    color: isActive ? colorScheme.primary.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: isActive ? Icon(Icons.bookmark, color: colorScheme.primary) : null,
                      title: Text(
                        _allChapters[index].title,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? colorScheme.primary : null,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); 
                        if (!isActive) _navigateToChapter(index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  itemCount: _currentViewItems.length,
                  itemBuilder: (context, index) {
                    final item = _currentViewItems[index];

                    // --- NAVIGATION BUTTONS ---
                    if (item.type == ItemType.navigation) {
                      return Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentChapterIndex > 0)
                              OutlinedButton.icon(
                                onPressed: () => _navigateToChapter(_currentChapterIndex - 1),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Previous"),
                              )
                            else
                              const SizedBox(width: 10),
                            
                            if (_currentChapterIndex < _allChapters.length - 1)
                              ElevatedButton.icon(
                                onPressed: () => _navigateToChapter(_currentChapterIndex + 1),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("Next Chapter"),
                                style: ElevatedButton.styleFrom(
                                  // ✅ BRAND BLUE FOR LIGHT MODE, THEME COLOR FOR DARK
                                  backgroundColor: isDark ? colorScheme.primary : const Color(0xFF06275C),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    // --- CONTENT ---
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
                        // ✅ CONTEXT MENU WITH COPY & MULTI-COLOR
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar(
                            anchors: editableTextState.contextMenuAnchors,
                            children: [
                              // 1. Copy Button
                              TextSelectionToolbarTextButton(
                                padding: const EdgeInsets.all(12.0),
                                onPressed: () {
                                  editableTextState.copySelection(SelectionChangedCause.toolbar);
                                  // Optional: Hide toolbar after copy
                                  editableTextState.hideToolbar();
                                },
                                child: const Icon(Icons.copy, size: 20),
                              ),
                              
                              // 2. Color Options
                              _buildColorButton(index, "0xFF81C784", Colors.green.shade300, editableTextState), // Green
                              _buildColorButton(index, "0xFFFFF59D", Colors.yellow.shade200, editableTextState), // Yellow
                              _buildColorButton(index, "0xFFFFB74D", Colors.orange.shade300, editableTextState), // Orange
                              _buildColorButton(index, "0xFFF06292", Colors.pink.shade300, editableTextState),   // Pink
                              _buildColorButton(index, "0xFF64B5F6", Colors.blue.shade300, editableTextState),   // Royal Blue

                              // 3. Clear Button
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

                // --- PROGRESS BAR ---
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: _chapterProgress == 0 ? 0.01 : _chapterProgress,
                        widthFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 32, 
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400, width: 1),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
          ]
        ),
      ),
    );
  }
}