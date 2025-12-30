import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sda_lesson_app/providers/data_providers.dart';
import 'package:sda_lesson_app/models/lesson_content.dart' as reader;
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // This defines 'File'
import 'dart:convert'; // This defines 'jsonEncode'

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
    // 1. Get the "Parent" path (e.g., transform '.../01/01' into '.../01')
    final List<String> pathSegments = lessonIndex.split('/');
    final String parentIndex = pathSegments.length > 3
        ? pathSegments.sublist(0, 3).join('/')
        : lessonIndex;

    // 2. Watch the PARENT index to get the 'days' list for the menu
    final asyncContent = ref.watch(lessonContentProvider(parentIndex));
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return asyncContent.when(
      data: (rawData) {
        final reader.LessonContent content = rawData;

        // Now 'daysList' will contain all 7 days because we loaded the parent index
        final List<reader.Day> daysList = content.days ?? [];

        if (daysList.isEmpty) {
          return const Scaffold(body: Center(child: Text("No days found.")));
        }

        // Find which day we are actually looking at from the original lessonIndex
        final String currentDayId = lessonIndex.split('/').last;
        final int activeDayIndex = daysList.indexWhere(
          (d) => d.id == currentDayId || d.index == currentDayId,
        );

        final int safeIndex = activeDayIndex != -1 ? activeDayIndex : 0;
        final reader.Day activeDay = daysList[safeIndex];

        // FIX: Use null-aware operator ?. to access cover
        final String? coverImage = content.lesson?.cover;

        return Scaffold(
          extendBodyBehindAppBar: true,
          drawer: !isDesktop
              ? _buildNavigationMenu(
                  context,
                  daysList,
                  safeIndex,
                  isDrawer: true,
                )
              : null,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: isDesktop
                ? const BackButton(color: Color.fromARGB(255, 8, 8, 8))
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
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
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  /* Your existing share logic */
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(
                4.0,
              ), // Height of the progress bar
              child: LinearProgressIndicator(
                // (activeIndex + 1) / totalDays gives us the percentage
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
          ),
          body: Row(
            children: [
              if (isDesktop)
                _buildNavigationMenu(
                  context,
                  daysList,
                  safeIndex,
                  isDrawer: false,
                ),
              Expanded(
                child: FutureBuilder<reader.LessonContent>(
                  // We fetch the SPECIFIC day content using the full lessonIndex (e.g., .../01/01)
                  future: ref.read(apiProvider).fetchLessonContent(lessonIndex),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Use the specific day data if it exists, otherwise fall back to menu data
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
                                  Text(
                                    studyDate.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  HtmlWidget(
                                    studyContent.isEmpty
                                        ? "No content available."
                                        : studyContent,
                                    textStyle: const TextStyle(
                                      fontSize:
                                          20, // Slightly larger for better readability
                                      height: 1.6, // Comfortable line spacing
                                      fontFamily:
                                          'Georgia', // Or your custom serif font
                                      color: Color(
                                        0xFF2C3E50,
                                      ), // Darker grey, easier on the eyes than pure black
                                    ),
                                    // Style specific HTML tags like <a> (Bible links)
                                    customStylesBuilder: (element) {
                                      if (element.localName == 'a') {
                                        return {
                                          'color':
                                              '#1A73E8', // Nice "Google Blue" for links
                                          'text-decoration': 'none',
                                          'font-weight': 'bold',
                                        };
                                      }
                                      return null;
                                    },
                                    onTapUrl: (url) {
                                      if (url.startsWith(
                                        'sabbath-school://bible',
                                      )) {
                                        _showBibleVerse(
                                          context,
                                          url,
                                          activeDay,
                                        );
                                        return true;
                                      }
                                      return false;
                                    },
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }

  Widget _buildNavigationMenu(
    BuildContext context,
    List<reader.Day> daysList,
    int activeIndex, {
    required bool isDrawer,
  }) {
    return Container(
      width: 300,
      // Ensure the background is solid white for the drawer
      color: isDrawer ? Colors.white : Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. NAVIGATION HEADER (Visible on Mobile/Drawer)
          if (isDrawer)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 10.0),
                child: Row(
                  children: [
                    IconButton(
                      // Changed to black for visibility on white background
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. LESSON TITLE SECTION
          Container(
            padding: EdgeInsets.fromLTRB(20, isDrawer ? 10 : 40, 20, 20),
            child: Text(
              lessonTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87, // High contrast text
              ),
            ),
          ),

          const Divider(height: 1), // Subtle separator
          // 3. DAYS LIST
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: daysList.length,
              itemBuilder: (context, index) {
                final reader.Day day = daysList[index];
                final bool isSelected = index == activeIndex;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    day.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                  ),
                  subtitle: Text(day.date),
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
  ) {
    final hasPrev = activeIndex > 0;
    final hasNext = activeIndex < daysList.length - 1;

    // Calculate current day for display (e.g., Day 1 of 7)
    final int currentDayNumber = activeIndex + 1;
    final int totalDays = daysList.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              // PREVIOUS BUTTON - ORANGE
              if (hasPrev)
                ElevatedButton(
                  onPressed: () =>
                      _navigateToDay(context, daysList, activeIndex - 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_ios, size: 18),
                )
              else
                const SizedBox(
                  width: 48,
                ), // Match button width to keep center label aligned
              // DAY PROGRESS LABEL
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "DAY $currentDayNumber",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                  Text(
                    "of $totalDays",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),

              // NEXT BUTTON - BLUE
              if (hasNext)
                ElevatedButton(
                  onPressed: () =>
                      _navigateToDay(context, daysList, activeIndex + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        image: (imageUrl != null && imageUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
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

  void _showBibleVerse(BuildContext context, String url, reader.Day activeDay) {
    final uri = Uri.parse(url);
    // Get reference (e.g., "John 3:16")
    final String verseReference = uri.queryParameters['verse'] ?? "Verse";
    final verseData = activeDay.bible?.firstWhere(
      (v) => v.name.replaceAll(' ', '') == verseReference.replaceAll(' ', ''),
      orElse: () => reader.BibleVerse(
        name: verseReference,
        content: "Verse text not available.",
      ),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to expand for long verses
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A small handle at the top for better UI
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  verseData?.name ?? verseReference,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            // 3. Use HtmlWidget here because verse content often contains <b> or <i> tags
            Flexible(
              child: SingleChildScrollView(
                child: HtmlWidget(
                  verseData?.content ?? "Content not found.",
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDownload(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Downloading lesson for offline use..."),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // 1. Fetch the data
      final content = await ref
          .read(apiProvider)
          .fetchLessonContent(lessonIndex);

      // 2. Get directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${lessonIndex.replaceAll('/', '_')}.json";
      final file = File('${directory.path}/$fileName');

      // 3. Save the file (requires the toJson changes in your model file)
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
