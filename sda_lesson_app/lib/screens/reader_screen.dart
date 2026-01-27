import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sda_lesson_app/providers/data_providers.dart';
import 'package:sda_lesson_app/models/lesson_content.dart' as reader;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'lesson_list_screen.dart';

// --- STATE PROVIDERS ---

// 1. Text Size Provider
final textSizeProvider = StateProvider<double>((ref) => 18.0);

// 2. Specific Day Content Provider (Handles Cache & API)
final specificDayContentProvider = FutureProvider.family<reader.LessonContent, String>((ref, lessonIndex) async {
  // A. Check for offline file first
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

  // B. If no cache, fetch from API
  return ref.read(apiProvider).fetchLessonContent(lessonIndex);
});

// ✅ CHANGED: Switched to ConsumerStatefulWidget to handle ScrollController
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
  // ✅ ADDED: Scroll Controller
  final ScrollController _scrollController = ScrollController();

  static const List<String> _dayNames = [
    "Sabbath", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"
  ];

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ Dispose controller to prevent leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    // Note: We don't watch textSizeProvider here globally to avoid rebuilding the whole scaffold
    // We pass it down or watch it inside the content widget.

    // Parsing IDs
    final List<String> pathSegments = widget.lessonIndex.split('/');
    final String parentIndex = pathSegments.length > 3
        ? pathSegments.sublist(0, 3).join('/')
        : widget.lessonIndex;
    final String quarterlyId = pathSegments.length >= 2
        ? "${pathSegments[0]}/${pathSegments[1]}"
        : "";

    // 1. Fetch Parent Data (Lesson Structure/Days list)
    final asyncParentContent = ref.watch(lessonContentProvider(parentIndex));
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return asyncParentContent.when(
      data: (rawData) {
        final reader.LessonContent content = rawData;
        final List<reader.Day> daysList = content.days ?? [];

        if (daysList.isEmpty) return _buildErrorBody(backgroundColor, "No days found.");

        // Identify active day
        final String currentDayId = widget.lessonIndex.split('/').last;
        final int activeDayIndex = daysList.indexWhere(
          (d) => d.id == currentDayId || d.index == currentDayId,
        );
        final int safeIndex = activeDayIndex != -1 ? activeDayIndex : 0;
        final reader.Day activeDay = daysList[safeIndex];

        // Cover Image Logic
        String? coverImage = content.lesson?.cover;
        if (coverImage != null && !coverImage.startsWith('http')) {
          coverImage = "https://sabbath-school.adventech.io/api/v1/$parentIndex/cover.png";
        }

        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: true, 
          
          // Drawer for Mobile
          drawer: !isDesktop
              ? _buildNavigationMenu(context, daysList, safeIndex, isDrawer: true, isDark: isDark)
              : null,
          
          appBar: _buildAppBar(context, ref, activeDay, safeIndex, daysList.length, quarterlyId, isDesktop),
          
          bottomNavigationBar: _buildBottomNavigation(context, daysList, safeIndex, isDark),
          
          body: Row(
            children: [
              // Sidebar for Desktop
              if (isDesktop)
                _buildNavigationMenu(context, daysList, safeIndex, isDrawer: false, isDark: isDark),
              
              Expanded(
                child: _buildMainContent(
                  ref, 
                  activeDay, 
                  coverImage, 
                  isDark
                ),
              ),
            ],
          ),
          
          // ✅ FIXED: Scroll to top button now works
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
      loading: () => Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => _buildErrorBody(backgroundColor, "Error loading lesson: $err"),
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
      bool isDesktop) {
    
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
              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)],
            ),
          ),
        ],
      ),
      leading: isDesktop
          ? const BackButton(color: Colors.white)
          : Builder(builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )),
      actions: [
        // Text Size Toggle
        IconButton(
          icon: const Icon(Icons.text_fields, color: Colors.white),
          tooltip: "Adjust Text Size",
          onPressed: () => _showTextSettings(context),
        ),
        IconButton(
          icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
          tooltip: "Quarterly Lessons",
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (quarterlyId.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => LessonListScreen(quarterlyId: quarterlyId, quarterlyTitle: "Lessons")
              ));
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
             final String shareUrl = "https://sabbath-school.adventech.io/${widget.lessonIndex}";
             Share.share('Check out this lesson: "${activeDay.title}"\n\n$shareUrl');
          },
        ),
        IconButton(
          icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white),
          onPressed: () => _handleDownload(context, ref),
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
      bool isDark) {
    
    // We watch the content here
    final asyncDayContent = ref.watch(specificDayContentProvider(widget.lessonIndex));
    // We watch the text size here so only this part rebuilds
    final textSize = ref.watch(textSizeProvider);

    return asyncDayContent.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Failed to load content: $err")),
      data: (displayData) {
        final String studyContent = displayData.content ?? activeDay.content;
        final String studyDate = displayData.date ?? activeDay.date;
        final htmlTextColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C3E50);

        return SingleChildScrollView(
          // ✅ ATTACHED SCROLL CONTROLLER
          controller: _scrollController,
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
                                color: isDark ? Colors.grey[400] : Colors.blueGrey,
                                letterSpacing: 1.2
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // HTML RENDERER
                            HtmlWidget(
                              studyContent.isEmpty ? "<p>No content available.</p>" : studyContent,
                              textStyle: TextStyle(
                                fontSize: textSize, // DYNAMIC TEXT SIZE
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
                                    'border-bottom': '1px dotted ${isDark ? '#64B5F6' : '#1A73E8'}',
                                  };
                                }
                                if (element.localName == 'blockquote') {
                                  return {
                                    'margin': '10px 0',
                                    'padding': '10px 15px',
                                    'background-color': isDark ? '#2C2C2C' : '#F5F5F5',
                                    'border-left': '4px solid ${isDark ? '#64B5F6' : '#1A73E8'}',
                                    'font-style': 'italic',
                                  };
                                }
                                return null;
                              },
                              onTapUrl: (url) async {
                                if (url.contains('bible')) {
                                  _showBibleVerse(context, url, activeDay, isDark);
                                  return true;
                                }
                                final uri = Uri.tryParse(url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        // ✅ FIXED: Wrapped in Consumer to listen to state changes inside modal
        return Consumer(
          builder: (context, ref, _) {
            final currentSize = ref.watch(textSizeProvider);
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Text Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                            // This updates the provider, triggering the Consumer to rebuild
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
      }
    );
  }

  // --- DOWNLOAD HANDLER ---
  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading lesson...")));
    try {
      final content = await ref.read(specificDayContentProvider(widget.lessonIndex).future);
      
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${widget.lessonIndex.replaceAll('/', '_')}.json";
      final file = File('${directory.path}/$fileName');
      
      final String jsonString = jsonEncode(content.toJson());
      await file.writeAsString(jsonString);
      
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Saved for offline reading!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Download failed: $e"), 
          backgroundColor: Colors.red
        ));
      }
    }
  }

  // --- BIBLE VERSE POPUP ---
  void _showBibleVerse(BuildContext context, String url, reader.Day activeDay, bool isDark) {
    final uri = Uri.parse(url);
    final String verseReference = uri.queryParameters['verse'] ?? "Verse";
    final String version = uri.queryParameters['version'] ?? "NKJV";

    final verseData = activeDay.bible?.firstWhere(
      (v) => v.name.replaceAll(RegExp(r'\s+'), '').toLowerCase() == verseReference.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
      orElse: () => reader.BibleVerse(name: verseReference, content: "<p>Verse content loading...</p>"),
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
            Center(child: Container(margin: const EdgeInsets.only(top: 10), height: 4, width: 40, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(verseData?.name ?? verseReference, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: Text(version, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: HtmlWidget(
                  verseData?.content ?? "<i>Verse text not found in local data.</i>",
                  textStyle: TextStyle(
                    fontSize: 18, 
                    height: 1.6, 
                    color: isDark ? Colors.grey[200] : Colors.grey[800]
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
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken)
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
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)]
          )
        ),
        child: Text(
          title, 
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 26, 
            fontWeight: FontWeight.bold, 
            fontFamily: 'Serif'
          )
        ),
      ),
    );
  }

  // --- NAVIGATION MENU ---
  Widget _buildNavigationMenu(BuildContext context, List<reader.Day> daysList, int activeIndex, {required bool isDrawer, required bool isDark}) {
    final bgColor = isDrawer ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) : (isDark ? const Color(0xFF121212) : Colors.grey[50]);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 300,
      color: bgColor,
      child: Column(
        children: [
          if (isDrawer)
             const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(20),
            child: Text(widget.lessonTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: daysList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final reader.Day day = daysList[index];
                final bool isSelected = index == activeIndex;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                  leading: Text("${index + 1}", style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold)),
                  title: Text(day.title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue : textColor)),
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
  Widget _buildBottomNavigation(BuildContext context, List<reader.Day> daysList, int activeIndex, bool isDark) {
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < daysList.length - 1;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Opacity(
                opacity: hasPrev ? 1.0 : 0.0,
                child: ElevatedButton.icon(
                  onPressed: hasPrev ? () => _navigateToDay(context, daysList, activeIndex - 1) : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text("Prev"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                ),
              ),
              
              Text("${activeIndex + 1} / ${daysList.length}", style: TextStyle(color: isDark ? Colors.grey : Colors.black54)),

              Opacity(
                opacity: hasNext ? 1.0 : 0.0,
                child: ElevatedButton.icon(
                  onPressed: hasNext ? () => _navigateToDay(context, daysList, activeIndex + 1) : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text("Next"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700], 
                    foregroundColor: Colors.white,
                  ).copyWith(
                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 12))
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDay(BuildContext context, List<reader.Day> daysList, int targetIndex) {
    final reader.Day targetDay = daysList[targetIndex];
    final List<String> segments = widget.lessonIndex.split('/');
    segments.removeLast();
    segments.add(targetDay.id);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ReaderScreen(lessonIndex: segments.join('/'), lessonTitle: widget.lessonTitle),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}