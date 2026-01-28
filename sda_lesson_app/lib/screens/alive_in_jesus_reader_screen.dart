import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import '../providers/data_providers.dart';

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
    // 1. FAST PATH: If PDF was passed in from the list screen, use it immediately.
    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      return _buildPdfViewer(pdfUrl!);
    }

    final asyncContent = ref.watch(lessonContentProvider(lessonId));
    const primaryColor = Color(0xFF06275C);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: asyncContent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (content) {
          // 2. CHECK API RESULT FOR PDF
          // Now that our model catches the PDF link, this check will pass!
          if (content.pdf != null && content.pdf!.isNotEmpty) {
             return _buildPdfViewer(content.pdf!);
          }

          // 3. CHECK FOR HTML TEXT
          if (content.content != null && content.content!.isNotEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Html(
                data: content.content,
                style: {
                  "body": Style(fontSize: FontSize(16), lineHeight: LineHeight(1.6)),
                },
              ),
            );
          }
          
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No text or PDF content found."),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPdfViewer(String url) {
    // Safety Check
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
      body: const PDF(
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: false,
      ).cachedFromUrl(
        url,
        placeholder: (progress) => Center(child: Text('$progress %')),
        errorWidget: (error) => Center(child: Text("PDF Error: $error")),
      ),
    );
  }
}