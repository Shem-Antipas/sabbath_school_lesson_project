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
    final id = guideData['id'];
    final title = guideData['title'] ?? 'Study Guide';
    final cover = guideData['cover'] ?? '';
    
    final asyncData = ref.watch(aliveInJesusDetailsProvider(id));
    const primaryColor = Color(0xFF06275C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildSingleResourceView(context, primaryColor, "Could not load list."),
        data: (details) {
          if (details == null || (details['lessons'] as List? ?? []).isEmpty) {
            return _buildSingleResourceView(context, primaryColor, null);
          }

          final lessons = details['lessons'] as List<dynamic>;
          final description = details['quarterly']['description'] ?? guideData['description'] ?? '';

          // 1. MASTER PDF CHECK (Check if the whole book is one PDF)
          String? masterPdf;
          final quarterlyData = details['quarterly'] as Map<String, dynamic>?;
          if (quarterlyData != null) {
             if (quarterlyData['pdf'] != null) masterPdf = quarterlyData['pdf'];
             else if (quarterlyData['pdfs'] != null && (quarterlyData['pdfs'] as List).isNotEmpty) {
               masterPdf = quarterlyData['pdfs'][0]['target'];
             }
          }

          return CustomScrollView(
            slivers: [
              _buildHeader(cover, description, primaryColor),
              SliverList(
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
                            // ✅ DEBUG: PRINT ALL KEYS TO FIND THE PDF
                            print("--------------------------------------------------");
                            print("🔍 INSPECTING LESSON DATA FOR: $lessonTitle");
                            lesson.forEach((key, value) => print("   $key: $value"));
                            print("--------------------------------------------------");

                            // ✅ AGGRESSIVE PDF FINDER
                            String? targetPdf;
                            
                            // Check all common locations
                            if (lesson['pdf'] != null && lesson['pdf'] is String) {
                               targetPdf = lesson['pdf'];
                            } else if (lesson['pdfs'] != null && (lesson['pdfs'] as List).isNotEmpty) {
                               targetPdf = lesson['pdfs'][0]['target'];
                            } else if (lesson['target'] != null) {
                               targetPdf = lesson['target'];
                            } else if (lesson['src'] != null) {
                               targetPdf = lesson['src'];
                            } else if (lesson['link'] != null) {
                               targetPdf = lesson['link'];
                            }
                            
                            // Fallback to Master PDF if specific lesson has none
                            targetPdf ??= masterPdf;

                            if (targetPdf == null) {
                              print("⚠️ NO PDF FOUND. Opening Reader to try text...");
                            } else {
                              print("✅ PDF FOUND: $targetPdf");
                            }
final fullIdForApi = "en/${guideData['id']}/${lesson['id']}";
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AliveInJesusReaderScreen(
                                  lessonId: fullIdForApi,
                                  title: lessonTitle,
                                  pdfUrl: targetPdf, 
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                      ],
                    );
                  },
                  childCount: lessons.length,
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
                imageUrl: url, width: 80, height: 120, fit: BoxFit.cover,
                errorWidget: (_,__,___) => Container(color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(desc, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleResourceView(BuildContext context, Color color, String? errorMsg) {
    return Center(child: Text(errorMsg ?? "No content"));
  }
}