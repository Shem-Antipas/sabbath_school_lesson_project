import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book_meta.dart';
import 'egw_book_detail_screen.dart';

class EGWTableOfContentsScreen extends StatefulWidget {
  final BookMeta bookMeta;

  const EGWTableOfContentsScreen({super.key, required this.bookMeta});

  @override
  State<EGWTableOfContentsScreen> createState() => _EGWTableOfContentsScreenState();
}

class _EGWTableOfContentsScreenState extends State<EGWTableOfContentsScreen> {
  List<dynamic> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final String response = await rootBundle.loadString(widget.bookMeta.filePath);
      final Map<String, dynamic> data = json.decode(response);
      
      setState(() {
        _chapters = data['chapters'];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading TOC: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. DETECT THEME ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // --- 2. DEFINE COLORS BASED ON THEME ---
    final appBarColor = isDark ? Colors.grey[900] : const Color(0xFF06275C);
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white70 : Colors.grey;
    
    // Chapter Number Bubble Colors
    final avatarBgColor = isDark ? Colors.grey[800] : const Color(0xFF06275C).withOpacity(0.1);
    final avatarTextColor = isDark ? Colors.white : const Color(0xFF06275C);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookMeta.title),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      leading: CircleAvatar(
                        // Use dynamic background color
                        backgroundColor: avatarBgColor,
                        child: Text(
                          "${chapter['chapter_number']}",
                          // Use dynamic text color
                          style: TextStyle(
                            color: avatarTextColor, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      title: Text(
                        chapter['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor, // Dynamic title color
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: iconColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EGWBookDetailScreen(
                              bookMeta: widget.bookMeta,
                              initialChapterIndex: index,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 70, color: isDark ? Colors.grey[800] : Colors.grey[300]), 
                  ],
                );
              },
            ),
    );
  }
}