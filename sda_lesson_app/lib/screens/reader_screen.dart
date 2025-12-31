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

class ReaderScreen extends ConsumerWidget {
  final String lessonIndex;
  final String lessonTitle;

  const ReaderScreen({
    super.key,
    required this.lessonIndex,
    required this.lessonTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. THEME DETECTION
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    // HTML Text: Dark Grey for Light Mode, Light Grey for Dark Mode
    final htmlTextColor = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF2C3E50);

    // Get the "Parent" path
    final List<String> pathSegments = lessonIndex.split('/');
    final String parentIndex = pathSegments.length > 3
        ? pathSegments.sublist(0, 3).join('/')
        : lessonIndex;

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

        // IMAGE URL LOGIC
        String? coverImage = content.lesson?.cover;
        if (coverImage != null && !coverImage.startsWith('http')) {
          coverImage =
              "https://sabbath-school.adventech.io/api/v1/$parentIndex/cover.png";
        }

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
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: isDesktop
                ? const BackButton(color: Colors.white)
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  final String title = activeDay.title;
                  final String htmlContent = activeDay.content;
                  final String plainText = htmlContent.replaceAll(
                    RegExp(r'<[^>]*>'),
                    '',
                  );
                  Share.share('$title\n\n$plainText');
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.download_for_offline_outlined,
                  color: Colors.white,
                ),
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
                child: FutureBuilder<reader.LessonContent>(
                  future: ref.read(apiProvider).fetchLessonContent(lessonIndex),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final displayData = snapshot.data;
                    final String studyContent =
                        displayData?.content ?? activeDay.content;
                    final String studyTitle =
                        displayData?.title ?? activeDay.title;
                    final String studyDate =
                        displayData?.date ?? activeDay.date;

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildHeaderImage(
                            content.lesson?.title ?? studyTitle,
                            coverImage,
                          ),
                          Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                100,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- 1. WRAP CONTENT IN SELECTIONAREA ---
                                  SelectionArea(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studyDate.toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.blueGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 15),

                                        // --- UPDATED HTML WIDGET ---
                                        HtmlWidget(
                                          studyContent.isEmpty
                                              ? "No content available."
                                              : studyContent,
                                          textStyle: TextStyle(
                                            fontSize: 20,
                                            height: 1.6,
                                            fontFamily: 'Georgia',
                                            color: htmlTextColor,
                                          ),
                                          customStylesBuilder: (element) {
                                            if (element.localName == 'a') {
                                              return {
                                                'color': isDark
                                                    ? '#64B5F6'
                                                    : '#1A73E8',
                                                'text-decoration': 'none',
                                                'font-weight': 'bold',
                                                'border-bottom':
                                                    '1px dotted ${isDark ? '#64B5F6' : '#1A73E8'}',
                                              };
                                            }
                                            return null;
                                          },
                                          onTapUrl: (url) async {
                                            // 1. Handle Internal Bible Links
                                            if (url.startsWith(
                                              'sabbath-school://bible',
                                            )) {
                                              _showBibleVerse(
                                                context,
                                                url,
                                                activeDay,
                                                isDark,
                                              );
                                              return true;
                                            }

                                            // 2. Handle External Web Links
                                            final uri = Uri.tryParse(url);
                                            if (uri != null &&
                                                await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
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
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            "Error: $err",
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  // --- BIBLE VERSE MODAL ---
  void _showBibleVerse(
    BuildContext context,
    String url,
    reader.Day activeDay,
    bool isDark,
  ) {
    final uri = Uri.parse(url);
    final String verseReference = uri.queryParameters['verse'] ?? "Verse";
    final String version = uri.queryParameters['version'] ?? "NIV";

    final verseData = activeDay.bible?.firstWhere(
      (v) =>
          v.name.replaceAll(' ', '').toLowerCase() ==
          verseReference.replaceAll(' ', '').toLowerCase(),
      orElse: () => reader.BibleVerse(
        name: verseReference,
        content: "<p><i>Verse content not found in lesson data.</i></p>",
      ),
    );

    final modalBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final headerColor = isDark ? Colors.grey[400] : Colors.blueGrey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verseData?.name ?? verseReference,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        version,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            const SizedBox(height: 10),

            // --- 2. WRAP VERSE CONTENT IN SELECTIONAREA ---
            Flexible(
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: HtmlWidget(
                    verseData?.content ?? "",
                    textStyle: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Georgia',
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS (Unchanged) ---

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
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(20, isDrawer ? 10 : 40, 20, 20),
            alignment: Alignment.centerLeft,
            child: Text(
              lessonTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
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

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: isDark
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.1),
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: isSelected
                        ? Colors.blue
                        : (isDark ? Colors.grey : Colors.grey),
                  ),
                  title: Text(
                    day.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.blue : secondaryTextColor,
                    ),
                  ),
                  subtitle: Text(
                    day.date,
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
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

  Widget _buildBottomNavigation(
    BuildContext context,
    List<reader.Day> daysList,
    int activeIndex,
    bool isDark,
  ) {
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < daysList.length - 1;
    final int currentDayNumber = activeIndex + 1;
    final int totalDays = daysList.length;

    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final labelColor = isDark ? Colors.grey[400] : Colors.blueGrey;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                ElevatedButton(
                  onPressed: () =>
                      _navigateToDay(context, daysList, activeIndex - 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_ios, size: 18),
                )
              else
                const SizedBox(width: 48),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "DAY $currentDayNumber",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: labelColor,
                    ),
                  ),
                  Text(
                    "of $totalDays",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[600] : Colors.grey[600],
                    ),
                  ),
                ],
              ),

              if (hasNext)
                ElevatedButton(
                  onPressed: () =>
                      _navigateToDay(context, daysList, activeIndex + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black),
          ],
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
    final List<String> segments = lessonIndex.split('/');
    segments.removeLast();
    segments.add(targetDay.id);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          lessonIndex: segments.join('/'),
          lessonTitle: lessonTitle,
        ),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Downloading lesson for offline use...")),
    );

    try {
      final content = await ref
          .read(apiProvider)
          .fetchLessonContent(lessonIndex);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${lessonIndex.replaceAll('/', '_')}.json";
      final file = File('${directory.path}/$fileName');
      final String jsonString = jsonEncode(content.toJson());
      await file.writeAsString(jsonString);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Success! This lesson is now available offline."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
