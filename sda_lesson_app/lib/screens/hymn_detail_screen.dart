import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Required for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'; 
import '../providers/hymnal_provider.dart';
// ✅ NEW: Import the MIDI player widget
import '../widgets/hymn_midi_player.dart';

class HymnDetailScreen extends ConsumerStatefulWidget {
  final Hymn initialHymn;
  final List<Hymn> allHymns;

  const HymnDetailScreen({
    super.key,
    required this.initialHymn,
    required this.allHymns,
  });

  @override
  ConsumerState<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends ConsumerState<HymnDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allHymns.indexOf(widget.initialHymn);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ✅ Helper to Copy Text (Logic preserved)
  void _copyToClipboard(Hymn hymn) {
    String formattedLyrics = _formatForClipboard(hymn.htmlContent);

    String copyText = """
${hymn.title}
${hymn.topic}

$formattedLyrics

Shared from Advent Study Hub
""";

    Clipboard.setData(ClipboardData(text: copyText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hymn copied with formatting!")),
    );
  }

  // ✅ Smart helper that turns HTML tags into real newlines (Logic preserved)
  String _formatForClipboard(String content) {
    if (!content.contains("<")) {
      return content;
    }

    String processed = content;
    processed = processed.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    processed = processed.replaceAll(RegExp(r'</(p|div)>', caseSensitive: false), '\n\n');
    processed = processed.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true), '');
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return processed.trim();
  }

  // Helper to strip HTML locally (Logic preserved)
  String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(hymnFontSizeProvider);
    final isKeepScreenOn = ref.watch(keepScreenOnProvider);

    // Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : const Color(0xFF7D2D3B);

    // ✅ Get the hymn currently being viewed (updates on swipe)
    final currentHymn = widget.allHymns[_currentIndex];
    
    // ✅ Logic to determine if MIDI should show (Assumes Hymn model has 'language')
    final bool showMidi = currentHymn.language == 'English';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Hymn ${currentHymn.id}",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.copy, color: iconColor),
            tooltip: "Copy to Clipboard",
            onPressed: () => _copyToClipboard(currentHymn),
          ),
          IconButton(
            icon: Icon(
              isKeepScreenOn ? Icons.lightbulb : Icons.lightbulb_outline,
              color: isKeepScreenOn ? Colors.orange : Colors.grey,
            ),
            tooltip: "Keep Screen On",
            onPressed: () =>
                ref.read(keepScreenOnProvider.notifier).state = !isKeepScreenOn,
          ),
          IconButton(
            icon: Icon(Icons.text_fields, color: iconColor),
            onPressed: () => _showFontControl(context, ref, isDark),
          ),
        ],
      ),
      // Wrap Body in SelectionArea to allow highlighting text
      body: SelectionArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.allHymns.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final hymn = widget.allHymns[index];
            return _buildHymnContent(hymn, fontSize, isDark);
          },
        ),
      ),
      // ✅ NEW: MIDI Player anchored to the bottom
      // It updates dynamically based on 'currentHymn'
      bottomNavigationBar: showMidi 
        ? HymnMidiPlayer(
            // Uses currentHymn.id for the filename (e.g. "1.mid")
            midiUrl: "assets/audio/hymns/${currentHymn.id}.mid", 
            hymnTitle: currentHymn.title,
            hymnNumber: currentHymn.id.toString(),
          )
        : null, 
    );
  }

  Widget _buildHymnContent(Hymn hymn, double fontSize, bool isDark) {
    bool isHtml = hymn.htmlContent.contains("<");

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            hymn.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle( 
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF7D2D3B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hymn.topic,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const Divider(height: 40, thickness: 1, indent: 50, endIndent: 50),

          // Content
          isHtml
              ? _buildHtmlContent(hymn.htmlContent, fontSize, isDark)
              : _buildPlainContent(hymn.htmlContent, fontSize, isDark),

          // ✅ Padding to ensure player doesn't cover text
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildHtmlContent(String htmlString, double fontSize, bool isDark) {
    return HtmlWidget(
      '<div style="text-align: center;">$htmlString</div>',
      textStyle: TextStyle(
        fontSize: fontSize,
        height: 1.6,
        color: isDark ? Colors.white : Colors.black87,
        fontFamily: 'Serif',
      ),
      customStylesBuilder: (element) {
        if (element.localName == 'h1') return {'display': 'none'};
        return null;
      },
    );
  }

  Widget _buildPlainContent(String text, double fontSize, bool isDark) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.6,
        fontFamily: 'Serif',
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  void _showFontControl(BuildContext context, WidgetRef ref, bool isDark) {
     showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentSize = ref.watch(hymnFontSizeProvider);
          final textColor = isDark ? Colors.white : Colors.black;

          return Container(
            padding: const EdgeInsets.all(25),
            height: 160,
            child: Column(
              children: [
                Text(
                  "ADJUST TEXT SIZE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.format_size, size: 16, color: Colors.grey[400]),
                    Expanded(
                      child: Slider(
                        activeColor: const Color(0xFF7D2D3B),
                        inactiveColor: isDark ? Colors.grey[700] : Colors.grey[300],
                        value: currentSize,
                        min: 16,
                        max: 40,
                        onChanged: (val) =>
                            ref.read(hymnFontSizeProvider.notifier).state = val,
                      ),
                    ),
                    const Icon(
                      Icons.format_size,
                      size: 32,
                      color: Color(0xFF7D2D3B),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}