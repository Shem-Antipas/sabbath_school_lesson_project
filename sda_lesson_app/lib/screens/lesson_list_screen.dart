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
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: asyncLessons.when(
            data: (lessons) {
              // Fallback image if a specific lesson has no cover
              final String rawQuarterlyCover =
                  "https://sabbath-school.adventech.io/api/v1/en/quarterlies/$quarterlyId/cover.png";

              return GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 30),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.7,
                ),
                itemCount: lessons.length,
                itemBuilder: (context, index) {
                  final lesson = lessons[index];

                  // --- FIX: REMOVE PROXY, USE DIRECT URL ---
                  // If lesson.cover exists, check if it's full URL. If not, construct it.
                  String imageUrl = lesson.cover ?? rawQuarterlyCover;

                  if (!imageUrl.startsWith('http')) {
                    // Construct full URL if it's a relative path
                    imageUrl =
                        "https://sabbath-school.adventech.io/api/v1/en/quarterlies/$quarterlyId/lessons/${lesson.id}/cover.png";
                    // Note: If the API doesn't provide lesson-specific covers,
                    // it often defaults to the quarterly cover.
                    // A safer fallback if specific covers fail is simply:
                    // imageUrl = rawQuarterlyCover;
                  }

                  return _buildLessonCard(
                    context,
                    lesson,
                    imageUrl, // Pass the fixed URL here
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
    String imageUrl,
    int index,
  ) {
    return InkWell(
      onTap: () {
        // Navigation Logic
        String lessonId = (lesson.id ?? "${index + 1}").padLeft(2, '0');
        String cleanQId = quarterlyId.contains('/')
            ? quarterlyId.split('/').last
            : quarterlyId;

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
              // Background Image
              Positioned.fill(
                child: Image.network(
                  imageUrl, // Using the direct URL now
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
