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

class ReaderScreen extends ConsumerWidget {
  final String lessonIndex;
  final String lessonTitle;

  const ReaderScreen({
    super.key,
    required this.lessonIndex,
    required this.lessonTitle,
  });

  static const List<String> _dayNames = [
    "Sabbath",
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday"
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final htmlTextColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2C3E50);

    // Extract Parent Index for data fetching
    final List<String> pathSegments = lessonIndex.split('/');
    final String parentIndex = pathSegments.length > 3
        ? pathSegments.sublist(0, 3).join('/')
        : lessonIndex;

    // Extract Quarterly ID for "Back to List" fallback
    final String quarterlyId = pathSegments.length >= 2 
        ? "${pathSegments[0]}/${pathSegments[1]}" 
        : "";

    final asyncContent = ref.watch(lessonContentProvider(parentIndex));
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return asyncContent.when(
      data: (rawData) {
        final reader.LessonContent content = rawData;
        final List<reader.Day> daysList = content.days ?? [];

        if (daysList.isEmpty) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: Center(
              child: Text(
                "No days found.",
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
          );
        }

        final String currentDayId = lessonIndex.split('/').last;
        final int activeDayIndex = daysList.indexWhere(
          (d) => d.id == currentDayId || d.index == currentDayId,
        );

        final int safeIndex = activeDayIndex != -1 ? activeDayIndex : 0;
        final reader.Day activeDay = daysList[safeIndex];

        String? coverImage = content.lesson?.cover;
        if (coverImage != null && !coverImage.startsWith('http')) {
          coverImage = "https://sabbath-school.adventech.io/api/v1/$parentIndex/cover.png";
        }

        return Scaffold(
          backgroundColor: backgroundColor,
          extendBodyBehindAppBar: true,
          drawer: !isDesktop
              ? _buildNavigationMenu(context, daysList, safeIndex, isDrawer: true, isDark: isDark)
              : null,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
            title: Text(
              lessonTitle, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)],
              ),
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
              // --- BUTTON: BACK TO LESSON LIST ---
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                tooltip: "Quarterly Lessons",
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else if (quarterlyId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LessonListScreen(
                          quarterlyId: quarterlyId,
                          quarterlyTitle: "Quarterly Lessons",
                        ),
                      ),
                    );
                  }
                },
              ),
              // --- UPDATED: SHARE LINK INSTEAD OF TEXT ---
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  final String title = activeDay.title;
                  // Construct the URL dynamically using the current lessonIndex
                  final String shareUrl = "https://sabbath-school.adventech.io/$lessonIndex";
                  Share.share('Check out this Sabbath School lesson: "$title"\n\n$shareUrl');
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
                value: (safeIndex + 1) / daysList.length,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 4,
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNavigation(context, daysList, safeIndex, isDark),
          body: Row(
            children: [
              if (isDesktop)
                _buildNavigationMenu(context, daysList, safeIndex, isDrawer: false, isDark: isDark),
              Expanded(
                child: FutureBuilder<reader.LessonContent>(
                  future: ref.read(apiProvider).fetchLessonContent(lessonIndex),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final displayData = snapshot.data;
                    final String studyContent = displayData?.content ?? activeDay.content;
                    final String studyDate = displayData?.date ?? activeDay.date;

                    return SingleChildScrollView(
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
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        
                                        HtmlWidget(
                                          studyContent.isEmpty ? "No content available." : studyContent,
                                          textStyle: TextStyle(
                                            fontSize: 20,
                                            height: 1.6,
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
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(backgroundColor: backgroundColor, body: Center(child: Text("Error: $err"))),
    );
  }

  // --- BEAUTIFUL BIBLE VERSE CARD ---
  void _showBibleVerse(BuildContext context, String url, reader.Day activeDay, bool isDark) {
    final uri = Uri.parse(url);
    final String verseReference = uri.queryParameters['verse'] ?? "Verse";
    final String version = uri.queryParameters['version'] ?? "NKJV";

    final verseData = activeDay.bible?.firstWhere(
      (v) => v.name.replaceAll(' ', '').toLowerCase() == verseReference.replaceAll(' ', '').toLowerCase(),
      orElse: () => reader.BibleVerse(name: verseReference, content: "<p>Verse content not found.</p>"),
    );

    final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF212121);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                child: Row(
                  children: ["NASB", "NKJV", "KJV", "ASV"].map((v) {
                    final isActive = v == version;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? (isDark ? Colors.grey[700] : Colors.grey[200]) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActive ? Colors.transparent : borderColor),
                      ),
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? textColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        verseData?.name ?? verseReference,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'sans-serif'),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SelectionArea(
                  child: HtmlWidget(
                    verseData?.content ?? "",
                    textStyle: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontFamily: 'Roboto',
                      color: textColor.withOpacity(0.9),
                    ),
                    customStylesBuilder: (element) {
                      if (element.localName == 'sup') return {'font-size': '0.7em', 'vertical-align': 'super'};
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- NAVIGATION MENU (Drawer) ---
  Widget _buildNavigationMenu(BuildContext context, List<reader.Day> daysList, int activeIndex, {required bool isDrawer, required bool isDark}) {
    final bgColor = isDrawer ? (isDark ? const Color(0xFF1E1E1E) : Colors.white) : (isDark ? const Color(0xFF121212) : Colors.grey[50]);
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.black87;

    return Container(
      width: 300,
      color: bgColor,
      child: Column(
        children: [
          if (isDrawer)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 10.0),
                child: Row(
                  children: [
                    IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
                    Text("Back", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(20, isDrawer ? 10 : 40, 20, 20),
            alignment: Alignment.centerLeft,
            child: Text(
              lessonTitle, 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: daysList.length,
              itemBuilder: (context, index) {
                final reader.Day day = daysList[index];
                final bool isSelected = index == activeIndex;
                
                final String dayLabel = day.title;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                  leading: Icon(
                    index < 7 ? Icons.calendar_today_outlined : Icons.book_outlined,
                    size: 18,
                    color: isSelected ? Colors.blue : (isDark ? Colors.grey : Colors.grey),
                  ),
                  title: Text(dayLabel, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue : secondaryTextColor)),
                  subtitle: Text(index < 7 ? day.date : "Extra", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])),
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

  // --- BOTTOM NAVIGATION ---
  Widget _buildBottomNavigation(BuildContext context, List<reader.Day> daysList, int activeIndex, bool isDark) {
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < daysList.length - 1;
    final int currentDayNumber = activeIndex + 1;
    final int totalDays = daysList.length;

    String currentDayName;
    if (activeIndex < _dayNames.length) {
      currentDayName = _dayNames[activeIndex];
    } else {
      currentDayName = daysList[activeIndex].title;
    }

    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey[400] : Colors.blueGrey;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasPrev)
                ElevatedButton(
                  onPressed: () => _navigateToDay(context, daysList, activeIndex - 1),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white, padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Icon(Icons.arrow_back_ios, size: 18),
                )
              else
                const SizedBox(width: 48),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentDayName.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: labelColor),
                    ),
                    Text(
                      "Section $currentDayNumber of $totalDays",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              if (hasNext)
                ElevatedButton(
                  onPressed: () => _navigateToDay(context, daysList, activeIndex + 1),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Icon(Icons.arrow_forward_ios, size: 18),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage(String title, String? imageUrl) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        image: (imageUrl != null && imageUrl.isNotEmpty)
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken))
            : null,
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(20),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black)])),
    );
  }

  void _navigateToDay(BuildContext context, List<reader.Day> daysList, int targetIndex) {
    final reader.Day targetDay = daysList[targetIndex];
    final List<String> segments = lessonIndex.split('/');
    segments.removeLast();
    segments.add(targetDay.id);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(lessonIndex: segments.join('/'), lessonTitle: lessonTitle),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading lesson for offline use...")));
    try {
      final content = await ref.read(apiProvider).fetchLessonContent(lessonIndex);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${lessonIndex.replaceAll('/', '_')}.json";
      final file = File('${directory.path}/$fileName');
      final String jsonString = jsonEncode(content.toJson());
      await file.writeAsString(jsonString);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success! This lesson is now available offline."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }
}