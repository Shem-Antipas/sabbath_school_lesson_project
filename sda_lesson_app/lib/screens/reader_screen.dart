import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/data_providers.dart';
import '../data/models/lesson_content.dart';
import 'package:http/http.dart' as http;
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
    final asyncContent = ref.watch(lessonContentProvider(lessonIndex));
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return asyncContent.when(
      data: (LessonContent? content) {
        // Guard 1: Null Content Check
        if (content == null) {
          return const Scaffold(
            body: Center(child: Text("No study material found for this day.")),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          drawer: !isDesktop
              ? _buildNavigationMenu(context, content, isDrawer: true)
              : null,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
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
                  final plainText =
                      content.content?.replaceAll(RegExp(r'<[^>]*>'), '') ?? "";
                  Share.share('${content.title ?? lessonTitle}\n\n$plainText');
                },
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigation(context, content),
          body: Row(
            children: [
              if (isDesktop)
                _buildNavigationMenu(context, content, isDrawer: false),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeaderImage(context, content),
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content.date?.toUpperCase() ??
                                    "DATE NOT AVAILABLE",
                                style: TextStyle(
                                  color: Colors.blueGrey[400],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 15),
                              // Guard 2: HTML Content Fallback
                              HtmlWidget(
                                content.content ??
                                    "<h3>Content coming soon.</h3>",
                                textStyle: const TextStyle(
                                  fontSize: 19,
                                  height: 1.6,
                                ),
                                customStylesBuilder: (element) {
                                  if (element.localName == 'a') {
                                    return {
                                      'color': '#1565C0',
                                      'text-decoration': 'underline',
                                      'font-weight': '600',
                                    };
                                  }
                                  return null;
                                },
                                onTapUrl: (url) {
                                  if (url.startsWith(
                                    'sabbath-school://bible',
                                  )) {
                                    _showBibleVerse(context, url);
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
                ),
              ),
            ],
          ),
        );
      },
      // Guard 3: Explicit Loading State
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      ),
      // Guard 4: Detailed Error State
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Something went wrong:\n$err",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationMenu(
    BuildContext context,
    LessonContent content, {
    required bool isDrawer,
  }) {
    // Guard 5: Safe mapping of days
    final List<LessonDay> days = content.days ?? [];

    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDrawer ? Colors.white : Colors.grey[50],
        border: isDrawer
            ? null
            : Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            width: double.infinity,
            color: isDrawer ? Colors.blueGrey[900] : Colors.transparent,
            child: Text(
              lessonTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDrawer ? Colors.white : Colors.blueGrey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                // Guard 6: Null index comparison
                final bool isCurrent =
                    day.index != null && lessonIndex.endsWith(day.index!);

                return ListTile(
                  selected: isCurrent,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.blue[800] : Colors.grey,
                    ),
                  ),
                  title: Text(
                    day.title ?? "Day ${index + 1}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent ? Colors.blue[800] : Colors.black87,
                    ),
                  ),
                  subtitle: day.date != null
                      ? Text(day.date!, style: const TextStyle(fontSize: 12))
                      : null,
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    if (day.index != null) _navigateToDay(context, day);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context, LessonContent content) {
    final days = content.days ?? [];
    final currentDayIndex = days.indexWhere(
      (day) => day.index != null && lessonIndex.endsWith(day.index!),
    );

    final hasPrev = currentDayIndex > 0;
    final hasNext = currentDayIndex != -1 && currentDayIndex < days.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (hasPrev)
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () =>
                      _navigateToDay(context, days[currentDayIndex - 1]),
                  child: const Text("PREVIOUS"),
                ),
              ),
            if (hasPrev && hasNext) const SizedBox(width: 15),
            if (hasNext)
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () =>
                      _navigateToDay(context, days[currentDayIndex + 1]),
                  child: const Text("NEXT"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage(BuildContext context, LessonContent content) {
    final parts = lessonIndex.split('/');
    final quarterlyId = parts.length > 1 ? parts[1] : "quarterly";
    final String proxiedUrl =
        "http://127.0.0.1:8787/proxy-image?url=${Uri.encodeComponent("https://sabbath-school.adventech.io/api/v1/images/global/$quarterlyId/cover.png")}";

    return Stack(
      children: [
        Container(
          height: 350,
          width: double.infinity,
          color: Colors.blueGrey[900], // Background color while loading
          child: Image.network(
            proxiedUrl,
            fit: BoxFit.cover,
            // Guard 7: Image Error Handling
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.blueGrey[800],
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.white30,
                size: 50,
              ),
            ),
          ),
        ),
        Container(
          height: 350,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
                Colors.white,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Text(
            content.title ?? "",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToDay(BuildContext context, LessonDay day) {
    if (day.index == null) return;

    final segments = lessonIndex.split('/');
    if (segments.length < 2) return; // Prevent crash on malformed index

    segments.removeLast();
    segments.add(day.index!);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => ReaderScreen(
          lessonIndex: segments.join('/'),
          lessonTitle: lessonTitle,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  // --- Bible Verse Methods ---
  Future<String> _fetchBibleText(String verse) async {
    final cleanVerse = Uri.encodeComponent(verse.replaceAll('+', ' '));
    final url = Uri.parse('https://bible-api.com/$cleanVerse');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? "Text not found.";
      }
      return "Could not load verse.";
    } catch (e) {
      return "Network error.";
    }
  }

  void _showBibleVerse(BuildContext context, String url) {
    final verse = Uri.parse(url).queryParameters['verse'] ?? "Verse not found";
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verse.replaceAll('+', ' '),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<String>(
                future: _fetchBibleText(verse),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    child: Text(
                      snapshot.data ?? "No text available.",
                      style: const TextStyle(fontSize: 18),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
