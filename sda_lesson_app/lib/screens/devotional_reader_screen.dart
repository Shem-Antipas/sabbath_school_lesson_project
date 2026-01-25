import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/devotional_provider.dart';

// --- MODEL FOR HIGHLIGHTS ---
class DevotionalHighlight {
  final String bookId;
  final int month;
  final int day;
  final int paragraphIndex; // Which paragraph in the reflowed text?
  final int startOffset;
  final int endOffset;
  final String colorHex;

  DevotionalHighlight({
    required this.bookId,
    required this.month,
    required this.day,
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    required this.colorHex,
  });

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'month': month,
    'day': day,
    'paragraphIndex': paragraphIndex,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'colorHex': colorHex,
  };

  factory DevotionalHighlight.fromJson(Map<String, dynamic> json) =>
      DevotionalHighlight(
        bookId: json['bookId'],
        month: json['month'],
        day: json['day'],
        paragraphIndex: json['paragraphIndex'],
        startOffset: json['startOffset'],
        endOffset: json['endOffset'],
        colorHex: json['colorHex'] ?? "0xFFFFF59D",
      );
}

// --- MAIN SCREEN ---
class DevotionalReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookTitle;
  final int monthIndex;
  final String monthName;
  final int initialDay;
  final String? searchQuery;

  const DevotionalReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.monthIndex,
    required this.monthName,
    required this.initialDay,
    this.searchQuery,
  });

  @override
  ConsumerState<DevotionalReaderScreen> createState() =>
      _DevotionalReaderScreenState();
}

class _DevotionalReaderScreenState
    extends ConsumerState<DevotionalReaderScreen> {
  PageController? _pageController;

  // FIX: Make this late so we can init it in initState
  late int _currentDay;
  bool _isInit = true;

  // Search Scrolling
  final GlobalKey _highlightKey = GlobalKey();

  // Highlighting State
  List<DevotionalHighlight> _userHighlights = [];
  TextSelection? _currentSelection;
  int? _focusedParagraphIndex; // Tracks which paragraph user is selecting

  @override
  void initState() {
    super.initState();
    // FIX: Initialize _currentDay immediately with the passed initialDay
    _currentDay = widget.initialDay;

    _loadUserHighlights();
    _saveReadingProgress(widget.initialDay);
  }

  // --- PERSISTENCE METHODS ---

  Future<void> _saveReadingProgress(int day) async {
    final prefs = await SharedPreferences.getInstance();
    // Save distinct progress per book
    await prefs.setInt('last_read_day_${widget.bookId}', day);
    await prefs.setInt('last_read_month_${widget.bookId}', widget.monthIndex);
  }

  Future<void> _loadUserHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('highlights_${widget.bookId}');
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      if (mounted) {
        setState(() {
          _userHighlights = jsonList
              .map((j) => DevotionalHighlight.fromJson(j))
              .toList();
        });
      }
    }
  }

  Future<void> _addHighlight(
    int paragraphIndex,
    TextSelection selection,
    String colorHex,
  ) async {
    if (!selection.isValid || selection.isCollapsed) return;

    // Remove overlapping highlights for cleanliness
    _userHighlights.removeWhere(
      (h) =>
          h.bookId == widget.bookId &&
          h.month == widget.monthIndex &&
          h.day == _currentDay &&
          h.paragraphIndex == paragraphIndex &&
          h.startOffset < selection.end &&
          h.endOffset > selection.start,
    );

    final newHighlight = DevotionalHighlight(
      bookId: widget.bookId,
      month: widget.monthIndex,
      day: _currentDay,
      paragraphIndex: paragraphIndex,
      startOffset: selection.start,
      endOffset: selection.end,
      colorHex: colorHex,
    );

    setState(() {
      _userHighlights.add(newHighlight);
      _currentSelection = null;
    });

    _saveHighlightsToPrefs();
  }

  Future<void> _clearHighlightsForParagraph(int paragraphIndex) async {
    setState(() {
      _userHighlights.removeWhere(
        (h) =>
            h.bookId == widget.bookId &&
            h.month == widget.monthIndex &&
            h.day == _currentDay &&
            h.paragraphIndex == paragraphIndex,
      );
    });
    _saveHighlightsToPrefs();
  }

  Future<void> _saveHighlightsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = json.encode(
      _userHighlights.map((h) => h.toJson()).toList(),
    );
    await prefs.setString('highlights_${widget.bookId}', jsonString);
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(devotionalContentProvider(widget.bookId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.grey[200] : Colors.grey[900];
    final verseColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // FIX: This now uses the correctly initialized _currentDay
        title: Text(
          "${widget.monthName} $_currentDay",
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              asyncData.whenData((allReadings) {
                final monthReadings = allReadings
                    .where((r) => r.month == widget.monthIndex)
                    .toList();
                monthReadings.sort((a, b) => a.day.compareTo(b.day));
                final currentReading = monthReadings.firstWhere(
                  (r) => r.day == _currentDay,
                  orElse: () => monthReadings[0],
                );
                _shareContent(currentReading, widget.bookTitle);
              });
            },
          ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (allReadings) {
          final monthReadings = allReadings
              .where((r) => r.month == widget.monthIndex)
              .toList();
          monthReadings.sort((a, b) => a.day.compareTo(b.day));

          if (monthReadings.isEmpty)
            return const Center(child: Text("No content."));

          // Initialize PageController only once
          if (_isInit) {
            int initialIndex = monthReadings.indexWhere(
              (r) => r.day == widget.initialDay,
            );
            if (initialIndex == -1) initialIndex = 0;
            _pageController = PageController(initialPage: initialIndex);

            // We do NOT set _currentDay here anymore because
            // it was already set in initState.

            _isInit = false;
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: monthReadings.length,
            // FIX: Ensure setState is called here to rebuild the AppBar title
            onPageChanged: (index) {
              final newDay = monthReadings[index].day;
              if (_currentDay != newDay) {
                setState(() {
                  _currentDay = newDay;
                  _currentSelection = null;
                });
                _saveReadingProgress(_currentDay);
              }
            },
            itemBuilder: (context, index) {
              final reading = monthReadings[index];
              final List<String> cleanParagraphs = _reflowText(reading.content);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    // TITLE
                    SelectableText(
                      reading.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.tealAccent
                            : const Color(0xFF7D2D3B),
                        fontFamily: 'Serif',
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // VERSE BOX
                    if (reading.verse.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[850]
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(color: Colors.teal, width: 4),
                          ),
                        ),
                        child: Column(
                          children: [
                            SelectableText(
                              reading.verse,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                                color: verseColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "- ${reading.verseRef}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.teal[200]
                                    : Colors.teal[800],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // PARAGRAPHS (With Custom Context Menu)
                    ...List.generate(cleanParagraphs.length, (paraIndex) {
                      final paraText = cleanParagraphs[paraIndex];

                      // Check for search query match to trigger auto-scroll
                      final bool containsSearch =
                          widget.searchQuery != null &&
                          widget.searchQuery!.isNotEmpty &&
                          paraText.toLowerCase().contains(
                            widget.searchQuery!.toLowerCase(),
                          );

                      if (containsSearch) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_highlightKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _highlightKey.currentContext!,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              alignment: 0.3,
                            );
                          }
                        });
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Container(
                          key: containsSearch ? _highlightKey : null,
                          child: SelectableText.rich(
                            TextSpan(
                              children: _buildRichText(
                                paraText,
                                widget.searchQuery,
                                paraIndex,
                                textColor,
                                isDark,
                              ),
                            ),
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.8,
                              color: textColor,
                              fontFamily: 'Serif',
                            ),
                            onSelectionChanged: (selection, cause) {
                              _currentSelection = selection;
                              _focusedParagraphIndex = paraIndex;
                            },
                            contextMenuBuilder: (context, editableTextState) {
                              return AdaptiveTextSelectionToolbar(
                                anchors: editableTextState.contextMenuAnchors,
                                children: [
                                  TextSelectionToolbarTextButton(
                                    padding: const EdgeInsets.all(12.0),
                                    onPressed: () {
                                      editableTextState.copySelection(
                                        SelectionChangedCause.toolbar,
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 20),
                                  ),
                                  _buildColorButton(
                                    paraIndex,
                                    "0xFF81C784",
                                    Colors.green,
                                    editableTextState,
                                  ),
                                  _buildColorButton(
                                    paraIndex,
                                    "0xFFFFF59D",
                                    Colors.yellow,
                                    editableTextState,
                                  ),
                                  _buildColorButton(
                                    paraIndex,
                                    "0xFF64B5F6",
                                    Colors.blue,
                                    editableTextState,
                                  ),
                                  _buildColorButton(
                                    paraIndex,
                                    "0xFFF06292",
                                    Colors.pink,
                                    editableTextState,
                                  ),
                                  TextSelectionToolbarTextButton(
                                    padding: const EdgeInsets.all(12.0),
                                    onPressed: () {
                                      _clearHighlightsForParagraph(paraIndex);
                                      editableTextState.hideToolbar();
                                    },
                                    child: const Icon(
                                      Icons.format_clear,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 50),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildColorButton(
    int index,
    String hex,
    Color color,
    EditableTextState state,
  ) {
    return InkWell(
      onTap: () {
        if (_currentSelection != null && _focusedParagraphIndex == index) {
          _addHighlight(index, _currentSelection!, hex);
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

  // --- TEXT PROCESSING ---

  List<TextSpan> _buildRichText(
    String text,
    String? query,
    int paraIndex,
    Color? baseColor,
    bool isDark,
  ) {
    List<Map<String, dynamic>> charStyles = List.generate(
      text.length,
      (index) => {'bgColor': null},
    );

    final myHighlights = _userHighlights.where(
      (h) =>
          h.bookId == widget.bookId &&
          h.month == widget.monthIndex &&
          h.day == _currentDay &&
          h.paragraphIndex == paraIndex,
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
          charStyles[i]['bgColor'] = isDark
              ? Colors.tealAccent.withOpacity(0.5)
              : Colors.yellow;
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
      if (style['bgColor'] != currentStyle['bgColor']) {
        spans.add(
          TextSpan(
            text: text.substring(currentStart, i),
            style: TextStyle(
              color: baseColor,
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
        style: TextStyle(
          color: baseColor,
          backgroundColor: currentStyle['bgColor'] as Color?,
        ),
      ),
    );

    return spans;
  }

  List<String> _reflowText(String rawContent) {
    String cleanContent = rawContent
        .replaceAll(RegExp(r'\[\d+\]'), '')
        .replaceAll(RegExp(r'\(\d+\)'), '')
        .replaceAllMapped(RegExp(r'(?<=[a-zA-Z])(?=\d)'), (match) => ' ')
        .replaceAllMapped(RegExp(r'(?<=\d)(?=[a-zA-Z])'), (match) => ' ')
        .replaceAllMapped(RegExp(r'(?<=[.!?])(?=[A-Z])'), (match) => ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (match) => ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    List<String> finalParagraphs = [];
    StringBuffer currentBuffer = StringBuffer();
    int sentenceCount = 0;

    RegExp sentenceSplit = RegExp(r'(?<=[.!?])\s+');
    List<String> allSentences = cleanContent.split(sentenceSplit);

    for (String sentence in allSentences) {
      String s = sentence.trim();
      if (s.isEmpty) continue;

      currentBuffer.write(s);
      currentBuffer.write(" ");
      sentenceCount++;

      if (sentenceCount >= 4) {
        finalParagraphs.add(currentBuffer.toString().trim());
        currentBuffer.clear();
        sentenceCount = 0;
      }
    }

    if (currentBuffer.isNotEmpty) {
      finalParagraphs.add(currentBuffer.toString().trim());
    }

    return finalParagraphs;
  }

  void _shareContent(DevotionalDay reading, String bookTitle) {
    List<String> cleanParas = _reflowText(reading.content);
    String formattedContent = cleanParas.join("\n\n");
    final String textToShare =
        """
*${reading.title}*
${widget.monthName} ${reading.day} | $bookTitle

"${reading.verse}" 
- ${reading.verseRef}

$formattedContent

_Sent from Advent Study Hub_
""";
    Share.share(textToShare);
  }
}
