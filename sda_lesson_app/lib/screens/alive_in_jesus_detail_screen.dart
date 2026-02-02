import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import 'alive_in_jesus_reader_screen.dart'; 

class AliveInJesusDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> guideData;

  const AliveInJesusDetailScreen({
    super.key,
    required this.guideData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Standardize IDs
    final String rawId = guideData['id'].toString();
    // Ensure we don't double up on the language prefix
    final String cleanId = rawId.startsWith('en/') ? rawId.substring(3) : rawId;
    
    final title = guideData['title'] ?? 'Study Guide';
    final cover = guideData['cover'] ?? guideData['fullCoverUrl'] ?? '';
    
    // We use the provider to fetch the detailed quarterly index (v2)
    final asyncData = ref.watch(aliveInJesusDetailsProvider(cleanId));
    const primaryColor = Color(0xFF06275C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildSingleResourceView(context, primaryColor, title, cover, "Tap to read this resource"),
        data: (details) {
          final lessons = details?['lessons'] as List? ?? [];
          final quarterly = details?['quarterly'] ?? guideData;
          final description = quarterly['description'] ?? '';

          // If there are NO sub-lessons, it's a single resource (like a specific handbook)
          if (lessons.isEmpty) {
            return _buildSingleResourceView(context, primaryColor, title, cover, description);
          }

          return CustomScrollView(
            slivers: [
              _buildHeader(cover, description, primaryColor),
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = lessons[index];
                      final lessonTitle = lesson['title'] ?? lesson['name'] ?? 'Lesson ${index + 1}';
                      final date = lesson['start_date'] ?? lesson['date'] ?? '';

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Text("${index + 1}", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(lessonTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            subtitle: date.isNotEmpty ? Text(date, style: TextStyle(color: Colors.grey[600])) : null,
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                            onTap: () {
  String cleanId = guideData['id'].toString();
  if (cleanId.startsWith('en/')) cleanId = cleanId.substring(3);

  String lessonId = lesson['id'].toString();
  
  // ✅ THE FIX: Cornerstone/RTF/PowerPoints need a 4th segment (/01)
  // if they don't have sub-days.
  String finalLessonId = "en/$cleanId/$lessonId";
  
  // If it's NOT an 'alive-in-jesus' lesson, Adventech usually 
  // stores the actual content at segment /01
  if (!finalLessonId.contains('alive-in-jesus')) {
    finalLessonId = "$finalLessonId/01"; 
  }

  debugPrint("🚀 Navigating to: $finalLessonId");

  String? targetPdf;
  if (lesson['pdf'] != null) targetPdf = lesson['pdf'];
  else if (lesson['pdfs'] != null && (lesson['pdfs'] as List).isNotEmpty) {
    targetPdf = lesson['pdfs'][0]['target'];
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AliveInJesusReaderScreen(
        lessonId: finalLessonId,
        title: lessonTitle,
        pdfUrl: targetPdf, 
      ),
    ),
  );
},
                          ),
                          const Divider(height: 1, indent: 70),
                        ],
                      );
                    },
                    childCount: lessons.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String url, String desc, Color color) {
    return SliverToBoxAdapter(
      child: Container(
        color: color.withOpacity(0.05),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: url, width: 100, height: 150, fit: BoxFit.cover,
                placeholder: (_,__) => Container(color: Colors.grey[200]),
                errorWidget: (_,__,___) => Container(color: Colors.grey, child: const Icon(Icons.book, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ABOUT THIS GUIDE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text(desc.isEmpty ? "No description available." : desc, 
                       maxLines: 6, overflow: TextOverflow.ellipsis, 
                       style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ IMPROVED: Build a proper CTA view for single-resource guides
  Widget _buildSingleResourceView(BuildContext context, Color color, String title, String cover, String desc) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(imageUrl: cover, height: 250, fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(desc, textAlign: TextAlign.center, maxLines: 3, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AliveInJesusReaderScreen(
                      lessonId: guideData['id'], 
                      title: title,
                    ),
                  ),
                );
              },
              child: const Text("READ RESOURCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}