import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/devotional_provider.dart';

// --- MODEL FOR HIGHLIGHTS ---
class DevotionalHighlight {
  final String bookId;
  final int month;
  final int day;
  final int paragraphIndex;
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
  final String coverImagePath; 
  final int monthIndex;
  final String monthName;
  final int initialDay;
  final String? searchQuery;

  const DevotionalReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.coverImagePath,
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

  late int _currentDay;
  bool _isInit = true;
  double _readingProgress = 0.0;

  double _fontSize = 18.0;

  final GlobalKey _highlightKey = GlobalKey();

  List<DevotionalHighlight> _userHighlights = [];
  TextSelection? _currentSelection;
  int? _focusedParagraphIndex;

  // ✅ AUDIO PLAYER VARIABLES
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  bool _showAudioPlayer = false;

  // ✅ AUDIO QUEUE SYSTEM (For Android compatibility)
  List<String> _audioQueue = [];
  int _currentQueueIndex = 0;

  // Progress tracking variables
  int _totalTextLength = 1;
  int _playedTextLength = 0;
  int _currentChunkProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentDay = widget.initialDay;
    _loadUserHighlights();
    _saveReadingProgress(widget.initialDay);
    _initTts(); 
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  // ✅ INITIALIZE TTS ENGINE
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(_speechRate);

    // Critical for queueing
    await flutterTts.awaitSpeakCompletion(true);

    // iOS Background Audio
    if (Platform.isIOS) {
      await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    // Android Background Service
    if (Platform.isAndroid) {
      try {
        var voices = await flutterTts.getVoices;
      } catch (e) {
        debugPrint("TTS Setup Warning: $e");
      }
    }

    flutterTts.setStartHandler(() {
      if (mounted) setState(() { _isSpeaking = true; _isPaused = false; });
    });

    flutterTts.setCompletionHandler(() {
      if (mounted) _onChunkComplete();
    });

    flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() { _isSpeaking = false; _isPaused = false; });
    });

    flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (mounted) setState(() { _currentChunkProgress = start; });
    });
  }

  void _onChunkComplete() {
    if (_currentQueueIndex < _audioQueue.length) {
      _playedTextLength += _audioQueue[_currentQueueIndex].length;
    }

    if (_currentQueueIndex < _audioQueue.length - 1) {
      _currentQueueIndex++;
      _playCurrentChunk();
    } else {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentQueueIndex = 0;
        _playedTextLength = 0;
        _currentChunkProgress = 0;
      });
    }
  }

  Future<void> _playCurrentChunk() async {
    if (_currentQueueIndex < _audioQueue.length) {
      await flutterTts.speak(_audioQueue[_currentQueueIndex]);
    }
  }

  // ✅ PREPARE AUDIO (Queue Logic)
  void _prepareAudioPanel() {
    if (_showAudioPlayer) {
      setState(() => _showAudioPlayer = false);
      _stop();
      return;
    }

    final asyncData = ref.read(devotionalContentProvider(widget.bookId));
    if (asyncData.value == null) return;

    final allReadings = asyncData.value!;
    final monthReadings = allReadings
        .where((r) => r.month == widget.monthIndex)
        .toList();
    final reading = monthReadings.firstWhere(
      (r) => r.day == _currentDay,
      orElse: () => monthReadings.first,
    );

    List<String> cleanParas = _reflowText(reading.content);
    String bodyText = cleanParas.join(". ");
    String fullText =
        "${reading.title}. ${reading.verse}. ${reading.verseRef}. $bodyText";

    // Split text into safe chunks
    List<String> chunks = [];
    RegExp splitRegex = RegExp(r'(?<=[.?!])\s+');
    List<String> sentences = fullText.split(splitRegex);

    StringBuffer buffer = StringBuffer();
    for (String sentence in sentences) {
      if (buffer.length + sentence.length > 3000) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(sentence);
      buffer.write(" ");
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());

    setState(() {
      _audioQueue = chunks;
      _currentQueueIndex = 0;
      _totalTextLength = fullText.length > 0 ? fullText.length : 1;
      _playedTextLength = 0;
      _currentChunkProgress = 0;
      _showAudioPlayer = true;
      _isSpeaking = false;
      _isPaused = false;
    });
  }

  Future<void> _togglePlay() async {
    if (_audioQueue.isEmpty) return;

    if (_isSpeaking && !_isPaused) {
      await _pause();
    } else {
      if (mounted) setState(() { _isSpeaking = true; _isPaused = false; });
      _playCurrentChunk();
    }
  }

  Future<void> _stop() async {
    await flutterTts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _showAudioPlayer = false;
        _currentQueueIndex = 0;
        _playedTextLength = 0;
        _currentChunkProgress = 0;
      });
    }
  }

  Future<void> _pause() async {
    await flutterTts.pause();
    if (mounted) setState(() { _isSpeaking = false; _isPaused = true; });
  }

  void _changeSpeed(double newRate) {
    setState(() => _speechRate = newRate);
    flutterTts.setSpeechRate(newRate);
    if (_isSpeaking && !_isPaused) {
      flutterTts.stop();
      _playCurrentChunk();
    }
  }

  void _showFullScreenPlayer() {
    final asyncData = ref.read(devotionalContentProvider(widget.bookId));
    if (asyncData.value == null) return;

    final allReadings = asyncData.value!;
    final monthReadings = allReadings
        .where((r) => r.month == widget.monthIndex)
        .toList();
    final reading = monthReadings.firstWhere(
      (r) => r.day == _currentDay,
      orElse: () => monthReadings.first,
    );

    double rawProgress =
        (_playedTextLength + _currentChunkProgress) / _totalTextLength;
    double safeProgress = rawProgress.clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullScreenDevotionalPlayer(
        bookTitle: widget.bookTitle,
        coverImagePath: widget.coverImagePath,
        dailyTitle: reading.title,
        dateString: "${widget.monthName} $_currentDay",
        isPlaying: _isSpeaking && !_isPaused,
        currentProgress: safeProgress,
        speechRate: _speechRate,
        onPlayPause: () {
          _togglePlay();
          Navigator.pop(context);
          _showFullScreenPlayer();
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

  // --- PERSISTENCE ---
  Future<void> _saveReadingProgress(int day) async {
    final prefs = await SharedPreferences.getInstance();
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

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Display Settings",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 14.0,
                          max: 32.0,
                          divisions: 9,
                          label: _fontSize.round().toString(),
                          onChanged: (val) {
                            setModalState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 28),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ MINI PLAYER WIDGET
  Widget _buildMiniPlayer() {
    if (!_showAudioPlayer) return const SizedBox.shrink();

    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[300];

    // ✅ FIX: Use White in dark mode for high visibility
    final iconColor = isDark ? Colors.white : Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: _showFullScreenPlayer,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor!)),
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
            // Cover Image
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                widget.coverImagePath,
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40, 
                    height: 60, 
                    color: Colors.grey,
                    child: const Icon(Icons.book, size: 20, color: Colors.white),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Day $_currentDay",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    widget.bookTitle,
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
            // Play/Pause
            IconButton(
              icon: Icon(
                _isSpeaking && !_isPaused
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
              ),
              iconSize: 40,
              // ✅ Applied High Contrast Color
              color: iconColor,
              onPressed: _togglePlay,
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(devotionalContentProvider(widget.bookId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.grey[200] : Colors.grey[900];
    final verseColor = isDark ? Colors.grey[400] : Colors.grey[800];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.monthName.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: isDark ? Colors.grey : Colors.grey[700],
              ),
            ),
            Text(
              "Day $_currentDay",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones),
            tooltip: "Listen",
            onPressed: _prepareAudioPanel,
          ),
          IconButton(
            icon: const Icon(Icons.format_size),
            tooltip: "Adjust Text Size",
            onPressed: _showDisplaySettings,
          ),
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
      bottomSheet: _showAudioPlayer ? _buildMiniPlayer() : null,

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

          if (_isInit) {
            int initialIndex = monthReadings.indexWhere(
              (r) => r.day == widget.initialDay,
            );
            if (initialIndex == -1) initialIndex = 0;
            _pageController = PageController(initialPage: initialIndex);
            _isInit = false;
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: monthReadings.length,
                onPageChanged: (index) {
                  final newDay = monthReadings[index].day;
                  if (_currentDay != newDay) {
                    setState(() {
                      _currentDay = newDay;
                      _currentSelection = null;
                      _readingProgress = 0.0;
                    });
                    if (_isSpeaking || _isPaused) _stop();
                    _saveReadingProgress(_currentDay);
                  }
                },
                itemBuilder: (context, index) {
                  final reading = monthReadings[index];
                  final List<String> cleanParagraphs = _reflowText(reading.content);

                  return NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      if (notification.metrics.axis == Axis.vertical) {
                        final metrics = notification.metrics;
                        final progress = metrics.maxScrollExtent == 0
                            ? 1.0
                            : metrics.pixels / metrics.maxScrollExtent;
                        if ((progress - _readingProgress).abs() > 0.01) {
                          Future.microtask(() {
                            if (mounted)
                              setState(
                                () => _readingProgress = progress.clamp(0.0, 1.0),
                              );
                          });
                        }
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      padding: _showAudioPlayer
                          ? const EdgeInsets.fromLTRB(20, 10, 20, 130)
                          : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        children: [
                          SelectableText(
                            reading.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _fontSize + 6,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent : const Color(0xFF7D2D3B),
                              fontFamily: 'Georgia',
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (reading.verse.isNotEmpty)
                            Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 30),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 25,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[850] : const Color(0xFFF9F9F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.teal.withOpacity(0.3)
                                          : Colors.grey.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      SelectableText(
                                        reading.verse,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: _fontSize,
                                          color: verseColor,
                                          height: 1.6,
                                          fontFamily: 'Georgia',
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        "- ${reading.verseRef}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: _fontSize - 2,
                                          color: isDark ? Colors.teal[200] : Colors.teal[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Icon(
                                    Icons.format_quote,
                                    color: Colors.grey.withOpacity(0.2),
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ...List.generate(cleanParagraphs.length, (paraIndex) {
                            final paraText = cleanParagraphs[paraIndex];
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
                              padding: const EdgeInsets.only(bottom: 18.0),
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
                                    fontSize: _fontSize,
                                    height: 1.8,
                                    color: textColor,
                                    fontFamily: 'Georgia',
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
                                          onPressed: () => editableTextState
                                              .copySelection(SelectionChangedCause.toolbar),
                                          child: const Icon(Icons.copy, size: 20),
                                        ),
                                        _buildColorButton(paraIndex, "0xFF81C784", Colors.green, editableTextState),
                                        _buildColorButton(paraIndex, "0xFFFFF59D", Colors.yellow, editableTextState),
                                        _buildColorButton(paraIndex, "0xFF64B5F6", Colors.blue, editableTextState),
                                        _buildColorButton(paraIndex, "0xFFF06292", Colors.pink, editableTextState),
                                        TextSelectionToolbarTextButton(
                                          padding: const EdgeInsets.all(12.0),
                                          onPressed: () {
                                            _clearHighlightsForParagraph(paraIndex);
                                            editableTextState.hideToolbar();
                                          },
                                          child: const Icon(Icons.format_clear, size: 20, color: Colors.red),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 20),
                          Divider(color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 20),
                          _buildBottomNavigation(context, index, monthReadings.length), // ✅ Added Back
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 2,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: _readingProgress == 0 ? 0.02 : _readingProgress,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ HELPER: Bottom Navigation (Restored)
  Widget _buildBottomNavigation(
    BuildContext context,
    int index,
    int totalLength,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (index > 0)
          OutlinedButton.icon(
            onPressed: () => _pageController?.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            label: const Text("Previous"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          )
        else
          const SizedBox(width: 10),
        if (index < totalLength - 1)
          ElevatedButton.icon(
            onPressed: () => _pageController?.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            icon: const Text("Next"),
            label: const Icon(Icons.arrow_forward_ios, size: 16),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
      ],
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
    if (currentBuffer.isNotEmpty)
      finalParagraphs.add(currentBuffer.toString().trim());
    return finalParagraphs;
  }

  void _shareContent(dynamic reading, String bookTitle) {
    List<String> cleanParas = _reflowText(reading.content);
    String formattedContent = cleanParas.join("\n\n");
    final String textToShare =
        "*${reading.title}*\n${widget.monthName} ${reading.day} | $bookTitle\n\n\"${reading.verse}\"\n- ${reading.verseRef}\n\n$formattedContent\n\n_Sent from Advent Study Hub_";
    Share.share(textToShare);
  }
}

// ✅ NEW FULL SCREEN PLAYER WIDGET
class FullScreenDevotionalPlayer extends StatelessWidget {
  final String bookTitle;
  final String coverImagePath;
  final String dailyTitle;
  final String dateString;
  final bool isPlaying;
  final double currentProgress;
  final double speechRate;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final Function(double) onChangeSpeed;
  final VoidCallback onClose;

  const FullScreenDevotionalPlayer({
    super.key,
    required this.bookTitle,
    required this.coverImagePath,
    required this.dailyTitle,
    required this.dateString,
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
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // ✅ FIX: High visibility colors in Dark Mode
    // Circle background: White in dark mode, Primary in light mode
    final circleColor = isDark ? Colors.white : Theme.of(context).primaryColor;
    // Icon color: Black in dark mode, White in light mode
    final iconColor = isDark ? Colors.black : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 15, bottom: 30),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
                  child: Image.asset(
                    coverImagePath, 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        Container(color: Colors.grey, child: Icon(Icons.book, size: 50, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  dailyTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateString,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<double>(
                value: speechRate,
                underline: Container(),
                icon: Icon(Icons.speed, color: textColor),
                dropdownColor: backgroundColor,
                style: TextStyle(color: textColor),
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
              CircleAvatar(
                radius: 35,
                // ✅ APPLIED FIX HERE
                backgroundColor: circleColor,
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 35,
                  ),
                  // ✅ APPLIED FIX HERE
                  color: iconColor,
                  onPressed: onPlayPause,
                ),
              ),
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