// lib/screens/alive_in_jesus_reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import '../models/lesson_content.dart'; 

class AliveInJesusReaderScreen extends ConsumerWidget {
  final String lessonId;
  final String title;
  final String? pdfUrl;

  const AliveInJesusReaderScreen({
    super.key,
    required this.lessonId,
    required this.title,
    this.pdfUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Immediate PDF check (Passed from previous screen)
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      return _buildPdfViewer(pdfUrl!);
    }

    final asyncContent = ref.watch(lessonContentProvider(lessonId));
    const primaryColor = Color(0xFF06275C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: asyncContent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text("Unable to load lesson content.\n$err", textAlign: TextAlign.center),
        )),
        data: (content) {
          // 2. INTERNAL PDF CHECK (If API JSON contains a PDF link)
          if (content.pdf != null && content.pdf!.isNotEmpty) {
            return _buildPdfViewer(content.pdf!);
          }

          // 3. DIRECT TEXT CONTENT CHECK
          // Corrects the "empty days" issue by rendering the main 'content' string
          if (content.content != null && content.content!.isNotEmpty) {
            return _buildReaderView(content, primaryColor);
          }

          // 4. TABLE OF CONTENTS / CHILDREN CHECK
          // Handles Cornerstone/Youth Hubs by listing the sections (e.g., Scripture, Inside Story)
          if (content.children != null && content.children!.isNotEmpty) {
            return _buildTableOfContents(context, content.children!, primaryColor);
          }

          // 5. MULTI-DAY FALLBACK (Standard Adult Structure)
          if (content.days != null && content.days!.isNotEmpty) {
            final firstDay = content.days!.first;
            final fallbackContent = LessonContent(
              content: firstDay.content,
              title: firstDay.title,
              cover: content.cover,
            );
            return _buildReaderView(fallbackContent, primaryColor);
          }

          // 6. EMPTY STATE
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "This section doesn't have text content yet.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- VIEW: READER (HTML Content) ---
  Widget _buildReaderView(LessonContent content, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Safety check for cover images to prevent FlutterJNI decode errors
          if (content.cover != null && content.cover!.startsWith('http'))
            CachedNetworkImage(
              imageUrl: content.cover!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
            
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
            child: Column(
              children: [
                Text(
                  content.title ?? title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                    color: Color(0xFF2C3E50),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.blueGrey, thickness: 0.5, indent: 50, endIndent: 50),
                const SizedBox(height: 20),
                Html(
                  data: content.content ?? "",
                  style: {
                    "body": Style(
                      fontSize: FontSize(18.5),
                      lineHeight: LineHeight(1.7),
                      color: Colors.black87,
                      textAlign: TextAlign.left,
                      margin: Margins.zero,
                    ),
                    "h1": Style(color: primaryColor, fontWeight: FontWeight.bold, fontSize: FontSize(22)),
                    "h2": Style(color: const Color(0xFF8D6E63), margin: Margins.only(top: 20)),
                    "blockquote": Style(
                      margin: Margins.only(left: 0, top: 10, bottom: 10),
                      padding: HtmlPaddings.all(15),
                      backgroundColor: Colors.grey[100],
                      fontStyle: FontStyle.italic,
                      border: Border(left: BorderSide(color: primaryColor, width: 4)),
                    ),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW: TABLE OF CONTENTS (Chapter List) ---
  Widget _buildTableOfContents(BuildContext context, List<LessonSection> chapters, Color primaryColor) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemCount: chapters.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 24, endIndent: 24),
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            radius: 18,
            child: Text("${index + 1}", style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: chapter.subtitle != null ? Text(chapter.subtitle!) : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: () {
            String newId = chapter.id;
            
            // Reconstruct nested ID (e.g., en/2026-01-cc/04 -> en/2026-01-cc/04/01)
            if (!newId.contains('/')) {
              final parts = lessonId.split('/');
              if (parts.length >= 2) {
                newId = "${parts[0]}/${parts[1]}/${chapter.id}";
                
                // If it's Cornerstone/Youth, Adventech text is often at the /01 index
                if (!newId.contains('alive-in-jesus') && parts.length == 3) {
                   newId = "$newId/01";
                }
              }
            }
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AliveInJesusReaderScreen(lessonId: newId, title: chapter.title),
              ),
            );
          },
        );
      },
    );
  }

  // --- VIEW: PDF VIEWER ---
  Widget _buildPdfViewer(String url) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF06275C),
        foregroundColor: Colors.white,
      ),
      body: const PDF(
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ).cachedFromUrl(
        url,
        placeholder: (progress) => Center(child: Text('Loading PDF: $progress%')),
        errorWidget: (error) => const Center(child: Text("Could not open PDF resource.")),
      ),
    );
  }
}