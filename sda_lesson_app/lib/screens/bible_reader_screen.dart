import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/bible_api_service.dart';
import '../providers/bible_provider.dart';

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String chapterId;  // Standard ID (e.g. "Gen.1")
  final String reference;  // Initial Display Name (e.g. "Genesis 1")
  final int? targetVerse;

  const BibleReaderScreen({
    super.key,
    required this.chapterId,
    required this.reference,
    this.targetVerse,
  });

  @override
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  final BibleApiService _api = BibleApiService();
  late Future<List<Map<String, String>>> _versesFuture;
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  double _fontSize = 18.0;
  final Set<int> _selectedIndices = {}; 
  List<Map<String, String>> _loadedVerses = [];
  
  // ✅ NEW: Dynamic Title State
  late String _currentReference; 

  @override
  void initState() {
    super.initState();
    _currentReference = widget.reference; // Set initial title

    final initialVersion = ref.read(bibleVersionProvider);
    _versesFuture = _api.fetchChapterVerses(widget.chapterId, version: initialVersion);
  }

  // --- MULTI-COPY FUNCTION ---
  void _copySelectedVerses() {
    if (_selectedIndices.isEmpty || _loadedVerses.isEmpty) return;

    final sortedIndices = _selectedIndices.toList()..sort();
    StringBuffer buffer = StringBuffer();

    // Get reference ranges
    String firstVerseNum = _loadedVerses[sortedIndices.first]['number'] ?? "";
    String lastVerseNum = _loadedVerses[sortedIndices.last]['number'] ?? "";
    
    // Clean up reference string (remove old chapter numbers if needed)
    String refString = _currentReference;
    if (refString.contains(':')) {
      refString = refString.split(':')[0]; 
    }

    if (sortedIndices.length > 1) {
      refString = "$refString:$firstVerseNum-$lastVerseNum";
    } else {
      refString = "$refString:$firstVerseNum";
    }

    final currentVersion = ref.read(bibleVersionProvider);
    refString = "$refString (${currentVersion.label})";

    for (int index in sortedIndices) {
      final verse = _loadedVerses[index];
      final num = verse['number'] ?? "";
      final text = verse['text'] ?? "";
      buffer.write("[$num] $text\n");
    }

    buffer.write("\n$refString");

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Copied ${sortedIndices.length} verses"),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _selectedIndices.clear();
    });
  }

  // ✅ HELPER: Update Title when Version Changes
  Future<void> _updateReferenceTitle(BibleVersion version) async {
    // 1. Extract Book ID from "Gen.1"
    final parts = widget.chapterId.split('.');
    if (parts.length < 2) return;
    
    final bookId = parts[0]; // "Gen"
    final chapterNum = parts[1]; // "1"

    // 2. Fetch all books for the NEW version
    final books = await _api.fetchBooks(version: version);
    
    // 3. Find the matching book name (e.g., "Chakruok")
    final match = books.firstWhere(
      (b) => b['id'] == bookId, 
      orElse: () => {'name': widget.reference.split(' ')[0]} // Fallback
    );

    // 4. Update State
    if (mounted) {
      setState(() {
        _currentReference = "${match['name']} $chapterNum";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for version changes
    ref.listen<BibleVersion>(bibleVersionProvider, (previous, next) {
      setState(() {
        _versesFuture = _api.fetchChapterVerses(widget.chapterId, version: next);
        _selectedIndices.clear(); 
      });
      // ✅ Update the App Bar Title (Genesis -> Chakruok)
      _updateReferenceTitle(next);
    });

    final currentVersion = ref.watch(bibleVersionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final selectionHighlight = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFE0B2);
    final searchHighlight = isDark ? const Color(0xFF263238) : const Color(0xFFFFF9C4);

    final bool hasSelection = _selectedIndices.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: hasSelection
            ? Text("${_selectedIndices.length} Selected", style: const TextStyle(fontSize: 18))
            : Column(
                children: [
                  // ✅ Use Dynamic Title Here
                  Text(_currentReference, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  Text(
                    currentVersion.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
        centerTitle: true,
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        leading: hasSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIndices.clear()),
              )
            : null,
        actions: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: "Copy Selection",
              onPressed: _copySelectedVerses,
            ),
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: "Switch Version",
            onPressed: () => _showVersionSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => setState(() => _fontSize = _fontSize == 18.0 ? 22.0 : 18.0),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Error loading content.", style: TextStyle(color: textColor)));
          }

          _loadedVerses = snapshot.data!;
          final verses = _loadedVerses;

          if (verses.isEmpty) {
            return Center(child: Text("Content not found for this version.", style: TextStyle(color: textColor)));
          }

          // Auto-scroll logic
          int initialIndex = 0;
          if (widget.targetVerse != null && verses.isNotEmpty) {
            initialIndex = (widget.targetVerse! - 1).clamp(0, verses.length - 1);
          }

          return ScrollablePositionedList.builder(
            itemCount: verses.length,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: initialIndex,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemBuilder: (context, index) {
              final verse = verses[index];
              final verseNum = verse['number'] ?? "0";
              final verseText = verse['text'] ?? "";
              
              final isSelected = _selectedIndices.contains(index);
              final isSearchTarget = widget.targetVerse != null && (int.tryParse(verseNum) == widget.targetVerse);

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
                    color: isSelected 
                        ? selectionHighlight 
                        : (isSearchTarget ? searchHighlight : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected || isSearchTarget
                        ? Border.all(color: Colors.orange, width: isSelected ? 2 : 1)
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
                                color: Colors.orange,
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
      floatingActionButton: hasSelection
          ? FloatingActionButton.extended(
              onPressed: _copySelectedVerses,
              backgroundColor: const Color(0xFF7D2D3B),
              icon: const Icon(Icons.copy, color: Colors.white),
              label: Text("Copy (${_selectedIndices.length})", style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  void _showVersionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final current = ref.watch(bibleVersionProvider);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select Version", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: BibleVersion.values.map((version) {
                        return ListTile(
                          title: Text(version.label),
                          subtitle: Text(version == BibleVersion.kjv ? "Standard Edition" : "Offline Translation"),
                          trailing: current == version ? const Icon(Icons.check_circle, color: Color(0xFF7D2D3B)) : null,
                          onTap: () {
                            ref.read(bibleVersionProvider.notifier).state = version;
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}