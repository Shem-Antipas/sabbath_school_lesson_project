import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/bible_api_service.dart';
import '../providers/bible_provider.dart';

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String chapterId;  // Initial ID (e.g. "Gen.1")
  final String reference;  // Initial Name (e.g. "Genesis 1")
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
  final ItemScrollController _itemScrollController = ItemScrollController();

  double _fontSize = 18.0;
  final Set<int> _selectedIndices = {}; 
  List<Map<String, String>> _loadedVerses = [];
  
  // --- STATE VARIABLES ---
  late String _currentChapterId;
  late String _currentReference;
  
  // Tracks the verse to scroll to AND highlight visually
  int? _highlightedVerseIndex; 

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.chapterId;
    _currentReference = widget.reference;
    
    // Set initial highlight if a target verse was passed
    if (widget.targetVerse != null) {
      _highlightedVerseIndex = widget.targetVerse! - 1;
    }

    _loadContent();
  }

  void _loadContent() {
    final currentVersion = ref.read(bibleVersionProvider);
    _versesFuture = _api.fetchChapterVerses(_currentChapterId, version: currentVersion);
  }

  // --- 1. NAVIGATION SHEET ---
  void _showQuickNavigationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _QuickNavContent(
            api: _api,
            version: ref.read(bibleVersionProvider),
            onVerseSelected: (bookId, bookName, chapterNum, verseNum) {
              Navigator.pop(context);
              setState(() {
                _currentChapterId = "$bookId.$chapterNum"; 
                _currentReference = "$bookName $chapterNum"; 
                _selectedIndices.clear();
                
                // Set the specific verse to highlight & scroll to
                _highlightedVerseIndex = (verseNum - 1);
                
                _loadContent();
              });
            },
          );
        },
      ),
    );
  }

  // --- 2. VERSION SWITCHER SHEET ---
  void _showVersionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentVersion = ref.watch(bibleVersionProvider);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Select Bible Version",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: BibleVersion.values.map((version) {
                        final isSelected = currentVersion == version;
                        return ListTile(
                          title: Text(
                            version.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF7D2D3B) : null,
                            ),
                          ),
                          subtitle: Text(
                            version == BibleVersion.kjv ? "Standard English" : "Offline Translation",
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Color(0xFF7D2D3B)) 
                            : null,
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
          },
        );
      },
    );
  }

  void _copySelectedVerses() {
    if (_selectedIndices.isEmpty || _loadedVerses.isEmpty) return;

    final sortedIndices = _selectedIndices.toList()..sort();
    StringBuffer buffer = StringBuffer();

    String firstVerseNum = _loadedVerses[sortedIndices.first]['number'] ?? "";
    String lastVerseNum = _loadedVerses[sortedIndices.last]['number'] ?? "";
    String refString = _currentReference.split(':')[0]; 

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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied selection"), duration: Duration(seconds: 1)));
    setState(() { _selectedIndices.clear(); });
  }

  Future<void> _updateReferenceTitle(BibleVersion version) async {
    final parts = _currentChapterId.split('.');
    if (parts.length < 2) return;
    
    final bookId = parts[0];
    final chapterNum = parts[1];

    final books = await _api.fetchBooks(version: version);
    
    final match = books.firstWhere(
      (b) => b['id'] == bookId, 
      orElse: () => {'name': _currentReference.split(' ')[0]} 
    );

    if (mounted) {
      setState(() {
        _currentReference = "${match['name']} $chapterNum";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BibleVersion>(bibleVersionProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _selectedIndices.clear();
          _loadContent(); 
        });
        _updateReferenceTitle(next);
      }
    });

    final currentVersion = ref.watch(bibleVersionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    // --- ✅ UPDATED COLORS FOR BETTER VISIBILITY ---
    
    // 1. Selection Color (User taps to copy) - Stays Warm/Orange
    final selectionColor = isDark 
        ? Colors.orange.withOpacity(0.3) 
        : const Color(0xFFFFE0B2); // Orange 100

    // 2. Target Verse Color (Jump destination) - NOW SOFT BLUE
    // Replaced Grey with Light Blue for clarity
    final targetVerseColor = isDark 
        ? Colors.lightBlue.withOpacity(0.15) 
        : Colors.lightBlue.withOpacity(0.25); 

    final bool hasSelection = _selectedIndices.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: hasSelection
            ? Text("${_selectedIndices.length} Selected", style: const TextStyle(fontSize: 18))
            : InkWell(
                onTap: _showQuickNavigationSheet,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_currentReference, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.7), size: 18)
                        ],
                      ),
                      Text(
                        currentVersion.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: textColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
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
            : BackButton(onPressed: () => Navigator.pop(context)),
        actions: [
          if (hasSelection)
            IconButton(
              icon: const Icon(Icons.copy),
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
          if (_loadedVerses.isEmpty) return const Center(child: Text("No Verses Found"));

          int safeScrollIndex = 0;
          if (_highlightedVerseIndex != null) {
            safeScrollIndex = _highlightedVerseIndex!.clamp(0, _loadedVerses.length - 1);
          }

          return ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemCount: _loadedVerses.length,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: safeScrollIndex,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemBuilder: (context, index) {
              final verse = _loadedVerses[index];
              final verseNum = verse['number'] ?? "0";
              final verseText = verse['text'] ?? "";
              
              final isSelected = _selectedIndices.contains(index);
              final isTarget = _highlightedVerseIndex == index;

              // ✅ Prioritize Selection Color over Target Color
              final bgColor = isSelected 
                  ? selectionColor 
                  : (isTarget ? targetVerseColor : Colors.transparent);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) _selectedIndices.remove(index);
                    else _selectedIndices.add(index);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    // Add distinct border if highlighted
                    border: isSelected 
                        ? Border.all(color: Colors.orange, width: 1.5)
                        : (isTarget ? Border.all(color: Colors.lightBlue.withOpacity(0.5), width: 1) : null),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: _fontSize, color: textColor, height: 1.6, fontFamily: "Serif"),
                      children: [
                        WidgetSpan(
                          child: Transform.translate(
                            offset: const Offset(0, -4),
                            child: Text("$verseNum ", style: TextStyle(fontSize: _fontSize * 0.6, color: const Color(0xFF7D2D3B), fontWeight: FontWeight.bold)),
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
    );
  }
}

class _QuickNavContent extends StatefulWidget {
  final BibleApiService api;
  final BibleVersion version;
  final Function(String id, String name, int chapter, int verse) onVerseSelected;

  const _QuickNavContent({
    required this.api,
    required this.version,
    required this.onVerseSelected,
  });

  @override
  State<_QuickNavContent> createState() => _QuickNavContentState();
}

class _QuickNavContentState extends State<_QuickNavContent> {
  int _mode = 0; 
  Map<String, dynamic>? _selectedBook;
  int? _selectedChapter;
  
  late Future<List<dynamic>> _booksFuture;
  int _verseCountForChapter = 0;
  bool _isLoadingVerses = false;

  @override
  void initState() {
    super.initState();
    _booksFuture = widget.api.fetchBooks(version: widget.version);
  }

  Future<void> _fetchVerseCount(String bookId, int chapter) async {
    setState(() => _isLoadingVerses = true);
    try {
      final verses = await widget.api.fetchChapterVerses("$bookId.$chapter", version: widget.version);
      if (mounted) {
        setState(() {
          _verseCountForChapter = verses.length;
          _isLoadingVerses = false;
          _mode = 2; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVerses = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String title = "Select Book";
    if (_mode == 1) title = "${_selectedBook!['name']}";
    if (_mode == 2) title = "${_selectedBook!['name']} $_selectedChapter";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (_mode > 0) 
                IconButton(
                  icon: const Icon(Icons.arrow_back), 
                  onPressed: () => setState(() => _mode--),
                ),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        if (_isLoadingVerses) const LinearProgressIndicator(color: Color(0xFF7D2D3B)),
        const Divider(height: 1),
        Expanded(child: _buildBody(isDark)),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_mode == 0) return _buildBookList(isDark);
    if (_mode == 1) return _buildGrid(isDark, count: _selectedBook!['chapters'] ?? 50, isChapters: true);
    return _buildGrid(isDark, count: _verseCountForChapter, isChapters: false);
  }

  Widget _buildBookList(bool isDark) {
    return FutureBuilder<List<dynamic>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final books = snapshot.data!;
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return ListTile(
              title: Text(book['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() {
                  _selectedBook = book;
                  _mode = 1; 
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(bool isDark, {required int count, required bool isChapters}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final number = index + 1;
        return InkWell(
          onTap: () {
            if (isChapters) {
              _selectedChapter = number;
              _fetchVerseCount(_selectedBook!['id'], number);
            } else {
              widget.onVerseSelected(
                _selectedBook!['id'], 
                _selectedBook!['name'], 
                _selectedChapter!,
                number 
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$number",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}