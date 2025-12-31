import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR CLIPBOARD
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/bible_api_service.dart';

class BibleReaderScreen extends StatefulWidget {
  final String chapterId;
  final String reference;
  final int? targetVerse;

  const BibleReaderScreen({
    super.key,
    required this.chapterId,
    required this.reference,
    this.targetVerse,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final BibleApiService _api = BibleApiService();
  late Future<List<Map<String, String>>> _versesFuture;
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  double _fontSize = 18.0;

  // CHANGED: Use a Set to store multiple selected verse INDICES
  final Set<int> _selectedIndices = {};

  // Store loaded verses so we can access them for copying without re-fetching
  List<Map<String, String>> _loadedVerses = [];

  @override
  void initState() {
    super.initState();
    _versesFuture = _api.fetchChapterVerses(widget.chapterId);
  }

  // --- MULTI-COPY FUNCTION ---
  void _copySelectedVerses() {
    if (_selectedIndices.isEmpty || _loadedVerses.isEmpty) return;

    // 1. Sort indices so verses copy in order (e.g. 1, 2, 3...)
    final sortedIndices = _selectedIndices.toList()..sort();

    // 2. Build the copy string
    StringBuffer buffer = StringBuffer();

    // Logic to create a nice reference string (e.g., "Gen 1:1-5")
    String firstVerseNum = _loadedVerses[sortedIndices.first]['number'] ?? "";
    String lastVerseNum = _loadedVerses[sortedIndices.last]['number'] ?? "";
    String refString = widget.reference;

    // If multiple verses, append the range to the reference
    if (sortedIndices.length > 1) {
      // e.g. "Genesis 1:1-8"
      refString = "${widget.reference}:$firstVerseNum-$lastVerseNum";
    } else {
      // e.g. "Genesis 1:1"
      refString = "${widget.reference}:$firstVerseNum";
    }

    // 3. Add Verse Texts
    for (int index in sortedIndices) {
      final verse = _loadedVerses[index];
      final num = verse['number'] ?? "";
      final text = verse['text'] ?? "";

      // Format: [8] And the sons of Ethan...
      buffer.write("[$num] $text\n");
    }

    // 4. Append Reference at the bottom
    buffer.write("\n($refString)");

    // 5. Send to Clipboard
    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied ${sortedIndices.length} verses to clipboard"),
        duration: const Duration(seconds: 2),
      ),
    );

    // Optional: Clear selection after copy
    setState(() {
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Highlights
    final searchHighlight = isDark
        ? const Color(0xFF2C3E50)
        : const Color(0xFFFFF9C4);
    final selectionHighlight = isDark
        ? const Color(0xFF3E2723)
        : const Color(0xFFFFE0B2);

    final bool hasSelection = _selectedIndices.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // Show selection count if selecting, otherwise show Chapter Title
        title: hasSelection
            ? Text(
                "${_selectedIndices.length} Selected",
                style: const TextStyle(fontSize: 18),
              )
            : Text(widget.reference),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        leading: hasSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIndices.clear()),
              )
            : null, // Default back button
        actions: [
          // 1. COPY BUTTON (Visible when verses selected)
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: "Copy Selection",
              onPressed: _copySelectedVerses,
            ),

          // 2. TEXT SIZE BUTTON
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () =>
                setState(() => _fontSize = _fontSize == 18.0 ? 22.0 : 18.0),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                "Error loading chapter.",
                style: TextStyle(color: textColor),
              ),
            );
          }

          _loadedVerses = snapshot.data!;
          final verses = _loadedVerses;

          int initialIndex = 0;
          if (widget.targetVerse != null) {
            initialIndex = (widget.targetVerse! - 1).clamp(
              0,
              verses.length - 1,
            );
          }

          return ScrollablePositionedList.builder(
            itemCount: verses.length,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: initialIndex,
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              80,
            ), // Extra padding for FAB if needed
            itemBuilder: (context, index) {
              final verse = verses[index];
              final verseNum = verse['number'] ?? "0";
              final verseText = verse['text'] ?? "";
              final verseNumInt = int.tryParse(verseNum) ?? 0;

              // Determine State
              final isSearchTarget =
                  widget.targetVerse != null &&
                  verseNumInt == widget.targetVerse;
              final isSelected = _selectedIndices.contains(index);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIndices.remove(index);
                    } else {
                      _selectedIndices.add(index);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // If selected, override search highlight
                    color: isSelected
                        ? selectionHighlight
                        : (isSearchTarget
                              ? searchHighlight
                              : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected || isSearchTarget
                        ? Border.all(
                            color: isSelected
                                ? Colors.orange
                                : Colors.orange.withOpacity(0.5),
                            width: isSelected ? 2 : 1,
                          )
                        : null,
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: textColor,
                        height: 1.6,
                        fontFamily: "Serif",
                      ),
                      children: [
                        WidgetSpan(
                          child: Transform.translate(
                            offset: const Offset(0, -4),
                            child: Text(
                              "$verseNum ",
                              style: TextStyle(
                                fontSize: _fontSize * 0.6,
                                color: isSelected ? Colors.orange : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: verseText),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // Optional: Add a Floating Action Button for easy Copying if selection exists
      floatingActionButton: hasSelection
          ? FloatingActionButton.extended(
              onPressed: _copySelectedVerses,
              backgroundColor: const Color(0xFF7D2D3B),
              icon: const Icon(Icons.copy, color: Colors.white),
              label: Text(
                "Copy (${_selectedIndices.length})",
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
