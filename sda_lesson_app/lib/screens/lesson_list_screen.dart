import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import 'reader_screen.dart';

class LessonListScreen extends ConsumerWidget {
  final String quarterlyId;
  final String quarterlyTitle;

  const LessonListScreen({
    super.key,
    required this.quarterlyId,
    required this.quarterlyTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLessons = ref.watch(lessonsProvider(quarterlyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(quarterlyTitle),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        // Centers the entire grid on wide screens
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ), // Standard web container width
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
          ), // Breathing room from page edges
          child: asyncLessons.when(
            data: (lessons) {
              final String rawQuarterlyCover =
                  "https://sabbath-school.adventech.io/api/v1/en/quarterlies/$quarterlyId/cover.png";

              return GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 30),
                // This makes the grid responsive (auto-adjusts columns based on width)
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280, // Target width for each tile
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.7, // Portrait book cover ratio
                ),
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];

                  // --- YOUR PROXY LOGIC ---
                  final String imageUrl = lesson.cover ?? rawQuarterlyCover;
                  final String proxiedImageUrl =
                      "http://127.0.0.1:8787/proxy-image?url=${Uri.encodeComponent(imageUrl)}";

                  return _buildLessonCard(
                    context,
                    lesson,
                    proxiedImageUrl,
                    index,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error: $err")),
          ),
        ),
      ),
    );
  }

  // --- REUSABLE COMPACT TILE UI ---
  Widget _buildLessonCard(
    BuildContext context,
    dynamic lesson,
    String proxiedImageUrl,
    int index,
  ) {
    return InkWell(
      onTap: () {
        // Navigation Logic
        String lessonId = (lesson.id ?? "${index + 1}").padLeft(2, '0');
        String cleanQId = quarterlyId.contains('/')
            ? quarterlyId.split('/').last
            : quarterlyId;

        // Matches the structure required by your fetch logic
        String finalIndex = "en/$cleanQId/$lessonId/01";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              lessonIndex: finalIndex,
              lessonTitle: lesson.title ?? "Lesson ${index + 1}",
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background Image via Proxy
              Positioned.fill(
                child: Image.network(
                  proxiedImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.blueGrey[900],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              // Bottom Gradient Overlay for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),

              // Text Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Lesson Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "LESSON ${index + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      lesson.title ?? "Lesson",
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
