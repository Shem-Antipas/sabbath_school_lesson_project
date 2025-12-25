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
      data: (LessonContent content) {
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
                  Share.share('${content.title}\n\n$plainText');
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
                                content.date?.toUpperCase() ?? "",
                                style: TextStyle(
                                  color: Colors.blueGrey[400],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 15),
                              HtmlWidget(
                                content.content ?? "",
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
    );
  }

  // --- UPDATED: CHRONOLOGICAL NAVIGATION MENU ---
  Widget _buildNavigationMenu(
    BuildContext context,
    LessonContent content, {
    required bool isDrawer,
  }) {
    final days = content.days ?? [];

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
                final bool isCurrent = lessonIndex.endsWith(day.index ?? "");

                return ListTile(
                  selected: isCurrent,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  // Displays "1", "2", etc. next to the title
                  leading: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.blue[800] : Colors.grey,
                    ),
                  ),
                  title: Text(
                    day.title ?? "Lesson Day",
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
                    _navigateToDay(context, day);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: BOTTOM NAV WITH COLORED BUTTONS ---
  Widget _buildBottomNavigation(BuildContext context, LessonContent content) {
    final currentDayIndex =
        content.days?.indexWhere(
          (day) => lessonIndex.endsWith(day.index ?? ""),
        ) ??
        -1;
    final hasPrev = currentDayIndex > 0;
    final hasNext =
        content.days != null && currentDayIndex < content.days!.length - 1;

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
                  onPressed: () => _navigateToDay(
                    context,
                    content.days![currentDayIndex - 1],
                  ),
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
                  onPressed: () => _navigateToDay(
                    context,
                    content.days![currentDayIndex + 1],
                  ),
                  child: const Text("NEXT"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // (Keeping _fetchBibleText, _showBibleVerse, _buildHeaderImage, and _navigateToDay as per your requirement)

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

  Widget _buildHeaderImage(BuildContext context, LessonContent content) {
    final parts = lessonIndex.split('/');
    final quarterlyId = parts.length > 1 ? parts[1] : "";
    final String proxiedUrl =
        "http://127.0.0.1:8787/proxy-image?url=${Uri.encodeComponent("https://sabbath-school.adventech.io/api/v1/images/global/$quarterlyId/cover.png")}";

    return Stack(
      children: [
        SizedBox(
          height: 350,
          width: double.infinity,
          child: Image.network(proxiedUrl, fit: BoxFit.cover),
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
    final segments = lessonIndex.split('/');
    segments.removeLast();
    segments.add(day.index!);
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
}
