import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sda_lesson_app/providers/data_providers.dart';
import 'package:sda_lesson_app/models/lesson_content.dart' as reader;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:convert';
import 'lesson_list_screen.dart';

// --- STATE PROVIDERS ---

final textSizeProvider = StateProvider<double>((ref) => 18.0);

final specificDayContentProvider =
    FutureProvider.family<reader.LessonContent, String>((
      ref,
      lessonIndex,
    ) async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = "${lessonIndex.replaceAll('/', '_')}.json";
        final file = File('${directory.path}/$fileName');

        if (await file.exists()) {
          final jsonString = await file.readAsString();
          return reader.LessonContent.fromJson(json.decode(jsonString));
        }
      } catch (e) {
        debugPrint("Cache read error: $e");
      }
      return ref.read(apiProvider).fetchLessonContent(lessonIndex);
    });

class ReaderScreen extends ConsumerStatefulWidget {
  final String lessonIndex;
  final String lessonTitle;

  const ReaderScreen({
    super.key,
    required this.lessonIndex,
    required this.lessonTitle,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();

  // ✅ AUDIO PLAYER VARIABLES
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  bool _showAudioPlayer = false;

  // ✅ PROGRESS TRACKING
  String _cachedAudioText = "";
  int _currentWordStart = 0;
  int _currentWordEnd = 0;
  int _totalTextLength = 1; // Default 1 to avoid division by zero

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  // ✅ INITIALIZE TTS ENGINE
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(_speechRate);

    await flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ], IosTextToSpeechAudioMode.defaultMode);

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

    // ✅ PROGRESS LISTENER
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

  // ✅ CLEAN HTML FOR AUDIO
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
  void _prepareAudioPanel(reader.Day activeDay, String? content) {
    if (_showAudioPlayer) {
      // Toggle visibility or keep open. Here we close if clicked again.
      setState(() => _showAudioPlayer = false);
      return;
    }

    String textToRead = content ?? activeDay.content;
    if (textToRead.isEmpty) return;

    String cleanText = _cleanHtmlForTts(textToRead);
    String fullAudio = "${activeDay.title}. \n\n $cleanText";

    setState(() {
      _cachedAudioText = fullAudio;
      _totalTextLength = fullAudio.length;
      _currentWordStart = 0;
      _showAudioPlayer = true;
      _isSpeaking = false;
      _isPaused = false;
    });
  }

  // ✅ 2. TOGGLE PLAY
  Future<void> _togglePlay() async {
    if (_cachedAudioText.isEmpty) return;

    if (_isSpeaking && !_isPaused) {
      await _pause();
    } else {
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
        _showAudioPlayer = false; // Hide panel on stop
        _currentWordStart = 0;
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
      flutterTts.speak(_cachedAudioText);
    }
  }

  // ✅ 3. SHOW FULL SCREEN PLAYER
  void _showFullScreenPlayer(reader.Day activeDay, String? coverImage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullScreenLessonPlayer(
        lessonTitle: widget.lessonTitle,
        dayTitle: activeDay.title,
        coverImage: coverImage,
        isPlaying: _isSpeaking && !_isPaused,
        currentProgress: (_currentWordStart / _totalTextLength).clamp(0.0, 1.0),
        speechRate: _speechRate,
        onPlayPause: () {
          _togglePlay();
          // Refresh modal state trick
          Navigator.pop(context);
          _showFullScreenPlayer(activeDay, coverImage);
        },
        onStop: () {
          _stop();
          Navigator.pop(context);
        },
        onChangeSpeed: (val) {
          _changeSpeed(val);
          Navigator.pop(context);
          _showFullScreenPlayer(activeDay, coverImage);
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  // --- MINI PLAYER WIDGET ---
  Widget _buildMiniPlayer(
    bool isDark,
    reader.Day activeDay,
    String? coverImage,
  ) {
    if (!_showAudioPlayer) return const SizedBox.shrink();

    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _showFullScreenPlayer(activeDay, coverImage), // Expand
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
            if (coverImage != null && coverImage.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  coverImage,
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey,
                    child: const Icon(Icons.broken_image, size: 20),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note, color: Colors.blue),
              ),

            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeDay.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    "Playing Lesson",
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
              color: Theme.of(context).primaryColor,
              onPressed: _togglePlay,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    final List<String> pathSegments = widget.lessonIndex.split('/');
    final String parentIndex = pathSegments.length > 3
        ? pathSegments.sublist(0, 3).join('/')
        : widget.lessonIndex;
    final String quarterlyId = pathSegments.length >= 2
        ? "${pathSegments[0]}/${pathSegments[1]}"
        : "";

    final asyncParentContent = ref.watch(lessonContentProvider(parentIndex));
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return asyncParentContent.when(
      data: (rawData) {
        final reader.LessonContent content = rawData;
        final List<reader.Day> daysList = content.days ?? [];

        if (daysList.isEmpty)
          return _buildErrorBody(backgroundColor, "No days found.");

        final String currentDayId = widget.lessonIndex.split('/').last;
        final int activeDayIndex = daysList.indexWhere(
          (d) => d.id == currentDayId || d.index == currentDayId,
        );
        final int safeIndex = activeDayIndex != -1 ? activeDayIndex : 0;
        final reader.Day activeDay = daysList[safeIndex];

        String? coverImage = content.lesson?.cover;
        if (coverImage != null && !coverImage.startsWith('http')) {
          coverImage =
              "https://sabbath-school.adventech.io/api/v1/$parentIndex/cover.png";
        }

        // We fetch data here to access content for audio prep
        final asyncDayContent = ref.watch(
          specificDayContentProvider(widget.lessonIndex),
        );

        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: true,
          drawer: !isDesktop
              ? _buildNavigationMenu(
                  context,
                  daysList,
                  safeIndex,
                  isDrawer: true,
                  isDark: isDark,
                )
              : null,

          appBar: _buildAppBar(
            context,
            ref,
            activeDay,
            safeIndex,
            daysList.length,
            quarterlyId,
            isDesktop,
            asyncDayContent.value?.content,
          ),

          // ✅ MINI PLAYER
          bottomSheet: _buildMiniPlayer(isDark, activeDay, coverImage),

          bottomNavigationBar: _buildBottomNavigation(
            context,
            daysList,
            safeIndex,
            isDark,
          ),

          body: Row(
            children: [
              if (isDesktop)
                _buildNavigationMenu(
                  context,
                  daysList,
                  safeIndex,
                  isDrawer: false,
                  isDark: isDark,
                ),

              Expanded(
                child: _buildMainContent(ref, activeDay, coverImage, isDark),
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            mini: true,
            backgroundColor: isDark ? Colors.grey[800] : Colors.blue,
            child: const Icon(Icons.arrow_upward, color: Colors.white),
            onPressed: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) =>
          _buildErrorBody(backgroundColor, "Error loading lesson: $err"),
    );
  }

  Widget _buildErrorBody(Color bgColor, String message) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(child: Text(message)),
    );
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    reader.Day activeDay,
    int safeIndex,
    int totalDays,
    String quarterlyId,
    bool isDesktop,
    String? contentToRead,
  ) {
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.4),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      title: Column(
        children: [
          Text(
            widget.lessonTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
      leading: isDesktop
          ? const BackButton(color: Colors.white)
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      actions: [
        // ✅ 1. HEADPHONE ICON
        IconButton(
          icon: const Icon(Icons.headphones, color: Colors.white),
          tooltip: "Listen",
          onPressed: () {
            _prepareAudioPanel(activeDay, contentToRead);
          },
        ),

        // 2. Text Size
        IconButton(
          icon: const Icon(Icons.text_fields, color: Colors.white),
          tooltip: "Adjust Text Size",
          onPressed: () => _showTextSettings(context),
        ),

        // 3. Popup Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'grid') {
              if (quarterlyId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonListScreen(
                      quarterlyId: quarterlyId,
                      quarterlyTitle: "Lessons",
                    ),
                  ),
                );
              }
            } else if (value == 'share') {
              final String shareUrl =
                  "https://sabbath-school.adventech.io/${widget.lessonIndex}";
              Share.share(
                'Check out this lesson: "${activeDay.title}"\n\n$shareUrl',
              );
            } else if (value == 'download') {
              _handleDownload(context, ref);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'grid',
              child: ListTile(
                leading: Icon(Icons.grid_view_rounded, color: Colors.black54),
                title: Text('Quarterly View'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share, color: Colors.black54),
                title: Text('Share Lesson'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem<String>(
              value: 'download',
              child: ListTile(
                leading: Icon(
                  Icons.download_for_offline_outlined,
                  color: Colors.black54,
                ),
                title: Text('Download Offline'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4.0),
        child: LinearProgressIndicator(
          value: (safeIndex + 1) / totalDays,
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          minHeight: 4,
        ),
      ),
    );
  }

  // --- MAIN CONTENT BODY ---
  Widget _buildMainContent(
    WidgetRef ref,
    reader.Day activeDay,
    String? coverImage,
    bool isDark,
  ) {
    final asyncDayContent = ref.watch(
      specificDayContentProvider(widget.lessonIndex),
    );
    final textSize = ref.watch(textSizeProvider);

    return asyncDayContent.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Failed to load content: $err")),
      data: (displayData) {
        final String studyContent = displayData.content ?? activeDay.content;
        final String studyDate = displayData.date ?? activeDay.date;
        final htmlTextColor = isDark
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF2C3E50);

        return SingleChildScrollView(
          controller: _scrollController,
          // ✅ PADDING FOR AUDIO PLAYER
          padding: _showAudioPlayer
              ? const EdgeInsets.only(bottom: 140)
              : EdgeInsets.zero,
          child: Column(
            children: [
              _buildHeaderImage(activeDay.title, coverImage),

              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studyDate.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.blueGrey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // HTML RENDERER
                            HtmlWidget(
                              studyContent.isEmpty
                                  ? "<p>No content available.</p>"
                                  : studyContent,
                              textStyle: TextStyle(
                                fontSize: textSize,
                                height: 1.7,
                                fontFamily: 'Georgia',
                                color: htmlTextColor,
                              ),
                              customStylesBuilder: (element) {
                                if (element.localName == 'a') {
                                  return {
                                    'color': isDark ? '#64B5F6' : '#1A73E8',
                                    'text-decoration': 'none',
                                    'font-weight': 'bold',
                                    'border-bottom':
                                        '1px dotted ${isDark ? '#64B5F6' : '#1A73E8'}',
                                  };
                                }
                                if (element.localName == 'blockquote') {
                                  return {
                                    'margin': '10px 0',
                                    'padding': '10px 15px',
                                    'background-color': isDark
                                        ? '#2C2C2C'
                                        : '#F5F5F5',
                                    'border-left':
                                        '4px solid ${isDark ? '#64B5F6' : '#1A73E8'}',
                                    'font-style': 'italic',
                                  };
                                }
                                return null;
                              },
                              onTapUrl: (url) async {
                                if (url.contains('bible')) {
                                  _showBibleVerse(
                                    context,
                                    url,
                                    activeDay,
                                    isDark,
                                  );
                                  return true;
                                }
                                final uri = Uri.tryParse(url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  return true;
                                }
                                return false;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TEXT SIZE SETTINGS MODAL ---
  void _showTextSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentSize = ref.watch(textSizeProvider);
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Text Size",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: currentSize,
                          min: 14.0,
                          max: 30.0,
                          divisions: 8,
                          label: currentSize.toStringAsFixed(1),
                          onChanged: (val) {
                            ref.read(textSizeProvider.notifier).state = val;
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 32),
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

  // --- DOWNLOAD HANDLER ---
  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Downloading lesson...")));
    try {
      final content = await ref.read(
        specificDayContentProvider(widget.lessonIndex).future,
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${widget.lessonIndex.replaceAll('/', '_')}.json";
      final file = File('${directory.path}/$fileName');

      final String jsonString = jsonEncode(content.toJson());
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved for offline reading!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- BIBLE VERSE POPUP ---
  void _showBibleVerse(
    BuildContext context,
    String url,
    reader.Day activeDay,
    bool isDark,
  ) {
    final uri = Uri.parse(url);
    final String verseReference = uri.queryParameters['verse'] ?? "Verse";
    final String version = uri.queryParameters['version'] ?? "NKJV";

    final verseData = activeDay.bible?.firstWhere(
      (v) =>
          v.name.replaceAll(RegExp(r'\s+'), '').toLowerCase() ==
          verseReference.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
      orElse: () => reader.BibleVerse(
        name: verseReference,
        content: "<p>Verse content loading...</p>",
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                height: 4,
                width: 40,
                color: Colors.grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      verseData?.name ?? verseReference,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      version,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: HtmlWidget(
                  verseData?.content ??
                      "<i>Verse text not found in local data.</i>",
                  textStyle: TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER IMAGE ---
  Widget _buildHeaderImage(String title, String? imageUrl) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        image: (imageUrl != null && imageUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'Serif',
          ),
        ),
      ),
    );
  }

  // --- NAVIGATION MENU ---
  Widget _buildNavigationMenu(
    BuildContext context,
    List<reader.Day> daysList,
    int activeIndex, {
    required bool isDrawer,
    required bool isDark,
  }) {
    final bgColor = isDrawer
        ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
        : (isDark ? const Color(0xFF121212) : Colors.grey[50]);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 300,
      color: bgColor,
      child: Column(
        children: [
          if (isDrawer) const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.lessonTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: daysList.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final reader.Day day = daysList[index];
                final bool isSelected = index == activeIndex;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: isDark
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.1),
                  leading: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    day.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.blue : textColor,
                    ),
                  ),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    _navigateToDay(context, daysList, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM NAV ---
  Widget _buildBottomNavigation(
    BuildContext context,
    List<reader.Day> daysList,
    int activeIndex,
    bool isDark,
  ) {
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < daysList.length - 1;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrev)
                ElevatedButton.icon(
                  onPressed: () {
                    _stop();
                    _navigateToDay(context, daysList, activeIndex - 1);
                  },
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text("Prev"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                )
              else
                const SizedBox(width: 10),

              Text(
                "${activeIndex + 1} / ${daysList.length}",
                style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
              ),

              if (hasNext)
                ElevatedButton.icon(
                  onPressed: () {
                    _stop();
                    _navigateToDay(context, daysList, activeIndex + 1);
                  },
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text("Next"),
                  style:
                      ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ).copyWith(
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDay(
    BuildContext context,
    List<reader.Day> daysList,
    int targetIndex,
  ) {
    final reader.Day targetDay = daysList[targetIndex];
    final List<String> segments = widget.lessonIndex.split('/');
    segments.removeLast();
    segments.add(targetDay.id);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ReaderScreen(
          lessonIndex: segments.join('/'),
          lessonTitle: widget.lessonTitle,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

// ✅ NEW FULL SCREEN PLAYER WIDGET
class FullScreenLessonPlayer extends StatelessWidget {
  final String lessonTitle;
  final String dayTitle;
  final String? coverImage;
  final bool isPlaying;
  final double currentProgress;
  final double speechRate;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final Function(double) onChangeSpeed;
  final VoidCallback onClose;

  const FullScreenLessonPlayer({
    super.key,
    required this.lessonTitle,
    required this.dayTitle,
    required this.coverImage,
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
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

          // Cover Image
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
                  child: (coverImage != null && coverImage!.isNotEmpty)
                      ? Image.network(coverImage!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey,
                          child: const Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  dayTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lessonTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Slider
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
