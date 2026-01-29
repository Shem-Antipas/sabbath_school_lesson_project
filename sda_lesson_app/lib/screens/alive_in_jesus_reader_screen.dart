// lib/screens/alive_in_jesus_reader_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import '../models/lesson_content.dart'; // Import for LessonSection

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
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      return _buildPdfViewer(pdfUrl!);
    }

    final asyncContent = ref.watch(lessonContentProvider(lessonId));
    const primaryColor = Color(0xFF06275C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: asyncContent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (content) {
          // 1. PDF CHECK
          if (content.pdf != null && content.pdf!.isNotEmpty) {
            return _buildPdfViewer(content.pdf!);
          }

          // 2. TEXT CONTENT CHECK (Show Reader)
          if (content.content != null && content.content!.isNotEmpty) {
            return _buildReaderView(content, primaryColor);
          }

          // 3. TABLE OF CONTENTS CHECK (Show List of Chapters)
          // This handles the "Book" case where no text exists yet
          if (content.children != null && content.children!.isNotEmpty) {
            return _buildTableOfContents(context, content.children!, primaryColor);
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No text, PDF, or chapters found."),
            ),
          );
        },
      ),
    );
  }

  // --- VIEW: READER (Text & Image) ---
  Widget _buildReaderView(LessonContent content, Color primaryColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.cover != null)
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(content.cover!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  content.title ?? content.subtitle ?? title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                    color: Color(0xFF8D6E63),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                Html(
                  data: content.content,
                  style: {
                    "body": Style(fontSize: FontSize(18), lineHeight: LineHeight(1.8), color: Colors.black87, margin: Margins.zero),
                    "h1": Style(fontSize: FontSize(22), color: primaryColor, fontWeight: FontWeight.bold),
                    "h2": Style(fontSize: FontSize(20), color: const Color(0xFF8D6E63), margin: Margins.only(top: 20)),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW: TABLE OF CONTENTS (List of Chapters) ---
  Widget _buildTableOfContents(BuildContext context, List<LessonSection> chapters, Color primaryColor) {
    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: chapter.subtitle != null ? Text(chapter.subtitle!) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 🚀 NAVIGATE TO THE SPECIFIC CHAPTER
              // We construct the new ID: en/quarterlyID/chapterID
              // Note: We need to reconstruct the full API ID carefully.
              // Assuming lessonId passed to this screen was "en/quarterly/parentID"
              
              // Simple heuristic: Take the base and append the chapter ID if it's not full
              String newId = chapter.id; 
              if (!newId.contains('/')) {
                 // If chapter ID is just "part-1...", we need to prepend context
                 final parts = lessonId.split('/'); // [en, 2025-01, growingwithjesus]
                 if(parts.length >= 2) {
                   newId = "${parts[0]}/${parts[1]}/${chapter.id}";
                 }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AliveInJesusReaderScreen(
                    lessonId: newId, 
                    title: chapter.title,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- VIEW: PDF VIEWER ---
  Widget _buildPdfViewer(String url) {
    if (!url.startsWith('http')) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error"), backgroundColor: const Color(0xFF06275C)),
        body: const Center(child: Text("Invalid PDF Link Found")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF06275C),
        foregroundColor: Colors.white,
      ),
      body: const PDF(enableSwipe: true, swipeHorizontal: false, autoSpacing: false, pageFling: false).cachedFromUrl(
        url,
        placeholder: (progress) => Center(child: Text('$progress %')),
        errorWidget: (error) => Center(child: Text("PDF Error: $error")),
      ),
    );
  }
}