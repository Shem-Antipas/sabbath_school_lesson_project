import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  RangeStyle({
    required this.start,
    required this.end,
    this.isBold = false,
    this.backgroundColor,
  });
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
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // ✅ AUDIO PLAYER VARIABLES
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  bool _showAudioPlayer = false;

  // ✅ AUDIO PROGRESS TRACKING
  String _cachedAudioText = "";
  int _currentWordStart = 0;
  int _currentWordEnd = 0;
  int _totalTextLength = 1; // Default to 1 to avoid division by zero

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
    _initTts(); // ✅ Init Audio
    _itemPositionsListener.itemPositions.addListener(_onScrollUpdate);
  }

  // ✅ INITIALIZE TTS ENGINE
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(_speechRate);

    // iOS Audio Config
    await flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ], IosTextToSpeechAudioMode.defaultMode);

    // Handlers
    flutterTts.setStartHandler(() {
      if (mounted)
        setState(() {
          _isSpeaking = true;
          _isPaused = false;
        });
    });

    flutterTts.setCompletionHandler(() {
      if (mounted)
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentWordStart = 0;
        });
    });

    flutterTts.setErrorHandler((msg) {
      if (mounted)
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
        });
    });

    // ✅ PROGRESS HANDLER
    flutterTts.setProgressHandler((
      String text,
      int start,
      int end,
      String word,
    ) {
      if (mounted) {
        setState(() {
          _currentWordStart = start;
          _currentWordEnd = end;
        });
      }
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScrollUpdate);
    flutterTts.stop();
    super.dispose();
  }

  // ✅ HELPER: STRIP HTML
  String _cleanHtmlForTts(String htmlContent) {
    String temp = htmlContent
        .replaceAll(RegExp(r'<br\s*/?>'), '. ')
        .replaceAll(RegExp(r'<\/p>'), '. ');

    temp = temp.replaceAll(RegExp(r'<[^>]*>'), '');

    temp = temp
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', ' and ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"');
    return temp;
  }

  // ✅ 1. PREPARE AUDIO (Headphone Click)
  void _prepareAudioPanel() {
    if (_showAudioPlayer) {
      setState(() => _showAudioPlayer = false);
      return;
    }

    if (_currentChapterIndex >= _allChapters.length) return;

    String title = _allChapters[_currentChapterIndex].title;
    String content = _cleanHtmlForTts(
      _allChapters[_currentChapterIndex].content,
    );
    String fullText = "$title. \n\n $content";

    setState(() {
      _cachedAudioText = fullText;
      _totalTextLength = fullText.length;
      _currentWordStart = 0;
      _showAudioPlayer = true;
      _isSpeaking = false; // Wait for user to click play
      _isPaused = false;
    });
  }

  // ✅ 2. TOGGLE PLAY (Safe Logic)
  Future<void> _togglePlay() async {
    if (_cachedAudioText.isEmpty) return;

    if (_isSpeaking && !_isPaused) {
      await _pause();
    } else {
      // Resume or Start
      if (mounted)
        setState(() {
          _isSpeaking = true;
          _isPaused = false;
        });
      await flutterTts.speak(_cachedAudioText);
    }
  }

  Future<void> _stop() async {
    await flutterTts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentWordStart = 0;
        _showAudioPlayer = false; // Hide panel on stop
      });
    }
  }

  Future<void> _pause() async {
    await flutterTts.pause();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = true;
      });
    }
  }

  void _changeSpeed(double newRate) {
    setState(() => _speechRate = newRate);
    flutterTts.setSpeechRate(newRate);
    if (_isSpeaking) {
      flutterTts.stop();
      flutterTts.speak(_cachedAudioText); // Restart to apply speed
    }
  }

  // ✅ 3. SHOW FULL SCREEN PLAYER
  void _showFullScreenPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullScreenAudioPlayer(
        bookMeta: widget.bookMeta,
        chapterTitle: _allChapters[_currentChapterIndex].title,
        isPlaying: _isSpeaking && !_isPaused,
        currentProgress: (_currentWordStart / _totalTextLength).clamp(0.0, 1.0),
        speechRate: _speechRate,
        onPlayPause: () {
          _togglePlay();
          Navigator.pop(context); // Close to refresh state
          _showFullScreenPlayer(); // Reopen immediately
        },
        onStop: () {
          _stop();
          Navigator.pop(context);
        },
        onChangeSpeed: (val) {
          _changeSpeed(val);
          Navigator.pop(context);
          _showFullScreenPlayer();
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _onScrollUpdate() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || _currentViewItems.isEmpty) return;

    final firstVisible = positions
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .reduce(
          (min, position) =>
              position.itemLeadingEdge < min.itemLeadingEdge ? position : min,
        );

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
    _saveLastReadPosition(currentIndex);
  }

  Future<void> _saveLastReadPosition(int scrollIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_read_chapter_${widget.bookMeta.id}',
      _currentChapterIndex,
    );
    await prefs.setInt('last_read_scroll_${widget.bookMeta.id}', scrollIndex);
  }

  Future<void> _loadUserHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(
      'highlights_${widget.bookMeta.id}',
    );
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _userHighlights = jsonList
            .map((j) => UserHighlight.fromJson(j))
            .toList();
      });
    }
  }

  Future<void> _addUserHighlight(
    int itemIndex,
    TextSelection selection,
    String colorHex,
  ) async {
    if (!selection.isValid || selection.isCollapsed) return;

    _userHighlights.removeWhere(
      (h) =>
          h.chapterIndex == _currentChapterIndex &&
          h.itemIndex == itemIndex &&
          h.startOffset < selection.end &&
          h.endOffset > selection.start,
    );

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

    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      _userHighlights.map((h) => h.toJson()).toList(),
    );
    await prefs.setString('highlights_${widget.bookMeta.id}', jsonString);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Highlight saved!"),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _clearHighlightsForItem(int itemIndex) async {
    setState(() {
      _userHighlights.removeWhere(
        (h) =>
            h.itemIndex == itemIndex && h.chapterIndex == _currentChapterIndex,
      );
    });
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      _userHighlights.map((h) => h.toJson()).toList(),
    );
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
    while (remaining.isNotEmpty) {
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

    return {'text': cleanBuffer.toString(), 'boldRanges': boldRanges};
  }

  Future<void> _loadBookData() async {
    try {
      final String response = await rootBundle.loadString(
        widget.bookMeta.filePath,
      );
      final Map<String, dynamic> data = json.decode(response);
      final List<dynamic> chapterList = data['chapters'];

      List<Chapter> tempChapters = [];
      for (int i = 0; i < chapterList.length; i++) {
        final c = chapterList[i];
        tempChapters.add(
          Chapter(
            number: c['chapter_number'] ?? i + 1,
            title: c['title'],
            content: c['content'],
          ),
        );
      }

      _allChapters = tempChapters;

      if (widget.initialChapterIndex == 0 && widget.initialIndex == 0) {
        final prefs = await SharedPreferences.getInstance();
        _currentChapterIndex =
            prefs.getInt('last_read_chapter_${widget.bookMeta.id}') ?? 0;
      }

      await _loadChapterIntoView(
        _currentChapterIndex,
        resetScroll: widget.initialIndex == 0,
      );

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

  Future<void> _loadChapterIntoView(
    int chapterIndex, {
    bool resetScroll = true,
  }) async {
    // ✅ Stop Audio & Hide Player on Chapter Change
    await _stop();
    if (mounted) setState(() => _showAudioPlayer = false);

    setState(() => _isLoading = true);

    if (chapterIndex < 0 || chapterIndex >= _allChapters.length) {
      setState(() => _isLoading = false);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 50));

    final Chapter c = _allChapters[chapterIndex];
    List<BookItem> tempItems = [];

    // Header
    tempItems.add(
      BookItem(
        type: ItemType.header,
        text: c.title.replaceAll(RegExp(r'<[^>]*>'), ''),
        chapterIndex: chapterIndex,
      ),
    );

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
          _addContentItem(
            tempItems,
            chunk,
            chapterIndex,
            fullBoldRanges,
            currentGlobalOffset,
          );
        } else {
          StringBuffer buffer = StringBuffer();
          int sentenceCount = 0;
          for (String s in sentences) {
            buffer.write(s.trim());
            buffer.write(" ");
            sentenceCount++;

            if (sentenceCount >= 8 || buffer.length > 800) {
              _addContentItem(
                tempItems,
                buffer.toString().trim(),
                chapterIndex,
                fullBoldRanges,
                currentGlobalOffset,
              );
              buffer.clear();
              sentenceCount = 0;
            }
          }
          if (buffer.isNotEmpty) {
            _addContentItem(
              tempItems,
              buffer.toString().trim(),
              chapterIndex,
              fullBoldRanges,
              currentGlobalOffset,
            );
          }
        }
      }
      currentGlobalOffset += paragraph.length + 2;
    }

    // Navigation Item
    tempItems.add(
      BookItem(type: ItemType.navigation, text: "", chapterIndex: chapterIndex),
    );

    if (mounted) {
      setState(() {
        _currentViewItems = tempItems;
        _currentChapterIndex = chapterIndex;
        _isLoading = false;
        _chapterProgress = 0.0;
      });

      if (resetScroll) {
        if (_itemScrollController.isAttached)
          _itemScrollController.jumpTo(index: 0);
      } else {
        final prefs = await SharedPreferences.getInstance();
        int savedScroll =
            prefs.getInt('last_read_scroll_${widget.bookMeta.id}') ?? 0;
        if (_itemScrollController.isAttached)
          _itemScrollController.jumpTo(index: savedScroll);
      }
    }
  }

  void _addContentItem(
    List<BookItem> items,
    String text,
    int chapterIndex,
    List<RangeStyle> fullBoldRanges,
    int globalOffset,
  ) {
    if (text.isEmpty) return;
    List<RangeStyle> chunkBoldRanges = [];
    items.add(
      BookItem(
        type: ItemType.content,
        text: text,
        chapterIndex: chapterIndex,
        boldRanges: chunkBoldRanges,
      ),
    );
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
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: index);
          timer.cancel();
        } else if (timer.tick > 20) {
          timer.cancel();
        }
      });
    }
  }

  List<TextSpan> _buildComplexText(
    BuildContext context,
    int itemIndex,
    BookItem item,
    String? query,
  ) {
    final String text = item.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHeader = item.type == ItemType.header;

    final Color textColor = isHeader
        ? (isDark ? Colors.white : const Color(0xFF06275C))
        : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);

    final TextStyle baseStyle = isHeader
        ? TextStyle(
            fontSize: _fontSize + 6,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
            height: 1.3,
          )
        : TextStyle(fontSize: _fontSize, height: 1.8, fontFamily: 'Georgia');

    List<Map<String, dynamic>> charStyles = List.generate(
      text.length,
      (index) => {'isBold': false, 'bgColor': null},
    );

    for (var r in item.boldRanges) {
      for (int i = r.start; i < r.end && i < text.length; i++) {
        charStyles[i]['isBold'] = true;
      }
    }

    final myHighlights = _userHighlights.where(
      (h) => h.chapterIndex == _currentChapterIndex && h.itemIndex == itemIndex,
    );
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
        for (
          int i = matchIndex;
          i < matchIndex + lowerQuery.length && i < text.length;
          i++
        ) {
          charStyles[i]['bgColor'] = Colors.yellow;
        }
        matchIndex = lowerText.indexOf(
          lowerQuery,
          matchIndex + lowerQuery.length,
        );
      }
    }

    List<TextSpan> spans = [];
    if (text.isEmpty) return spans;

    int currentStart = 0;
    var currentStyle = charStyles[0];

    for (int i = 1; i < text.length; i++) {
      var style = charStyles[i];
      if (style['isBold'] != currentStyle['isBold'] ||
          style['bgColor'] != currentStyle['bgColor']) {
        spans.add(
          TextSpan(
            text: text.substring(currentStart, i),
            style: baseStyle.copyWith(
              color: textColor,
              fontWeight: (currentStyle['isBold'] as bool)
                  ? FontWeight.bold
                  : FontWeight.normal,
              backgroundColor: currentStyle['bgColor'] as Color?,
            ),
          ),
        );
        currentStart = i;
        currentStyle = style;
      }
    }
    spans.add(
      TextSpan(
        text: text.substring(currentStart),
        style: baseStyle.copyWith(
          color: textColor,
          fontWeight: (currentStyle['isBold'] as bool)
              ? FontWeight.bold
              : FontWeight.normal,
          backgroundColor: currentStyle['bgColor'] as Color?,
        ),
      ),
    );

    return spans;
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Display Settings",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                            setModalState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 30),
                    ],
                  ),
                  const Center(
                    child: Text(
                      "Drag to adjust text size",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ MINI AUDIO PLAYER (Expandable)
  Widget _buildMiniPlayer(bool isDark) {
    if (!_showAudioPlayer) return const SizedBox.shrink();

    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: _showFullScreenPlayer, // ✅ EXPAND ON CLICK
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.3))),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                widget.bookMeta.coverImage,
                width: 40,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // Title & Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _allChapters[_currentChapterIndex].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    widget.bookMeta.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Play/Pause Button
            IconButton(
              icon: Icon(
                _isSpeaking && !_isPaused
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
              ),
              iconSize: 40,
              color: Theme.of(context).primaryColor,
              onPressed: _togglePlay, // Local toggle
            ),
          ],
        ),
      ),
    );
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
          // ✅ AUDIO BUTTON (Prepares only)
          IconButton(
            icon: const Icon(Icons.headphones),
            tooltip: "Listen",
            onPressed: _prepareAudioPanel,
          ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _allChapters.length,
                itemBuilder: (context, index) {
                  bool isActive = index == _currentChapterIndex;
                  return Container(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      leading: isActive
                          ? Icon(
                              Icons.bookmark,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      title: Text(
                        _allChapters[index].title,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : null,
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
      // ✅ MINI PLAYER AT BOTTOM
      bottomSheet: _showAudioPlayer ? _buildMiniPlayer(isDark) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ScrollablePositionedList.builder(
                  // Padding for mini player
                  padding: _showAudioPlayer
                      ? const EdgeInsets.only(bottom: 90)
                      : EdgeInsets.zero,
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  itemCount: _currentViewItems.length,
                  itemBuilder: (context, index) {
                    final item = _currentViewItems[index];
                    if (item.type == ItemType.navigation) {
                      return Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentChapterIndex > 0)
                              OutlinedButton.icon(
                                onPressed: () => _navigateToChapter(
                                  _currentChapterIndex - 1,
                                ),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Previous"),
                              )
                            else
                              const SizedBox(width: 10),
                            if (_currentChapterIndex < _allChapters.length - 1)
                              ElevatedButton.icon(
                                onPressed: () => _navigateToChapter(
                                  _currentChapterIndex + 1,
                                ),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("Next Chapter"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Theme.of(context).colorScheme.primary
                                      : const Color(0xFF06275C),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: item.type == ItemType.header
                          ? const EdgeInsets.fromLTRB(20, 40, 20, 20)
                          : const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                      child: SelectableText.rich(
                        TextSpan(
                          children: _buildComplexText(
                            context,
                            index,
                            item,
                            widget.searchQuery,
                          ),
                        ),
                        textAlign: item.type == ItemType.header
                            ? TextAlign.center
                            : TextAlign.justify,
                        onSelectionChanged: (selection, cause) {
                          _currentSelection = selection;
                          _focusedItemIndex = index;
                        },
                        contextMenuBuilder: (context, editableTextState) =>
                            AdaptiveTextSelectionToolbar(
                              anchors: editableTextState.contextMenuAnchors,
                              children: [
                                TextSelectionToolbarTextButton(
                                  padding: const EdgeInsets.all(12.0),
                                  onPressed: () {
                                    editableTextState.copySelection(
                                      SelectionChangedCause.toolbar,
                                    );
                                    editableTextState.hideToolbar();
                                  },
                                  child: const Icon(Icons.copy, size: 20),
                                ),
                                _buildColorButton(
                                  index,
                                  "0xFF81C784",
                                  Colors.green.shade300,
                                  editableTextState,
                                ),
                                TextSelectionToolbarTextButton(
                                  padding: const EdgeInsets.all(12.0),
                                  onPressed: () {
                                    _clearHighlightsForItem(index);
                                    editableTextState.hideToolbar();
                                  },
                                  child: const Icon(
                                    Icons.format_clear,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    );
                  },
                ),
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
                        heightFactor: _chapterProgress == 0
                            ? 0.01
                            : _chapterProgress,
                        widthFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
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

  Widget _buildColorButton(
    int index,
    String hex,
    Color color,
    EditableTextState state,
  ) {
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
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ NEW FULL SCREEN AUDIO PLAYER WIDGET
class FullScreenAudioPlayer extends StatelessWidget {
  final BookMeta bookMeta;
  final String chapterTitle;
  final bool isPlaying;
  final double currentProgress;
  final double speechRate;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final Function(double) onChangeSpeed;
  final VoidCallback onClose;

  const FullScreenAudioPlayer({
    super.key,
    required this.bookMeta,
    required this.chapterTitle,
    required this.isPlaying,
    required this.currentProgress,
    required this.speechRate,
    required this.onPlayPause,
    required this.onStop,
    required this.onChangeSpeed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // 90% height
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Close Handle
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 30),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Book Cover
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(bookMeta.coverImage, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Text Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  chapterTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bookMeta.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Progress Bar (Visual Only for TTS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${(currentProgress * 100).toInt()}% Read",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed
              DropdownButton<double>(
                value: speechRate,
                underline: Container(),
                icon: const Icon(Icons.speed),
                items: [0.3, 0.5, 0.75, 1.0, 1.25]
                    .map(
                      (rate) => DropdownMenuItem(
                        value: rate,
                        child: Text("${rate}x"),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) onChangeSpeed(val);
                },
              ),

              // Play/Pause
              CircleAvatar(
                radius: 35,
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 35,
                  ),
                  color: Colors.white,
                  onPressed: onPlayPause,
                ),
              ),

              // Stop/Close
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, size: 35),
                color: Colors.redAccent,
                onPressed: onStop,
              ),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
