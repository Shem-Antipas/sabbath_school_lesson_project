import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'; 
import '../providers/hymnal_provider.dart';
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

  // --- 🔍 FIXED: SEARCH & KEYPAD LOGIC ---

  void _showHymnSearchDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      // 1. Rename this context to 'dialogContext' to avoid confusion
      builder: (dialogContext) {
        String inputNumber = "";
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black;

            void handlePress(String value) {
              if (value == 'GO') {
                // 2. Pass 'dialogContext' explicitly to the jump function
                _jumpToHymn(inputNumber, dialogContext);
              } else {
                setDialogState(() {
                  if (value == 'DEL') {
                    if (inputNumber.isNotEmpty) {
                      inputNumber = inputNumber.substring(0, inputNumber.length - 1);
                    }
                  } else {
                    if (inputNumber.length < 4) {
                      inputNumber += value;
                    }
                  }
                });
              }
            }

            return Dialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Go to Hymn Number",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 15),
                    
                    // Display Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black38 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: inputNumber.isNotEmpty 
                              ? const Color(0xFF7D2D3B) 
                              : Colors.transparent, 
                          width: 2
                        ),
                      ),
                      child: Center(
                        child: Text(
                          inputNumber.isEmpty ? "- - -" : inputNumber,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF7D2D3B),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Keypad Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12, 
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      itemBuilder: (context, index) {
                        String label;
                        if (index < 9) {
                          label = '${index + 1}'; 
                        } else if (index == 9) {
                          label = 'DEL';
                        } else if (index == 10) {
                          label = '0';
                        } else {
                          label = 'GO';
                        }

                        bool isGo = label == 'GO';
                        bool isDel = label == 'DEL';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => handlePress(label),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isGo 
                                  ? const Color(0xFF7D2D3B) 
                                  : (isDark ? Colors.grey[800]! : Colors.white),
                                borderRadius: BorderRadius.circular(10),
                                border: isGo ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
                                boxShadow: isGo ? [
                                  BoxShadow(
                                    color: const Color(0xFF7D2D3B).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4)
                                  )
                                ] : null,
                              ),
                              child: isDel
                                ? Icon(Icons.backspace_rounded, color: textColor, size: 22)
                                : Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isGo ? Colors.white : textColor,
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ FIXED: Takes 'dialogContext' to pop the correct window
  void _jumpToHymn(String numberStr, BuildContext dialogContext) {
    if (numberStr.isEmpty) return;

    int? searchId = int.tryParse(numberStr);
    
    final index = widget.allHymns.indexWhere((h) {
      return h.id.toString() == numberStr || (searchId != null && h.id == searchId);
    });

    if (index != -1) {
      // 1. Close the Dialog (using the dialog's context)
      Navigator.pop(dialogContext); 
      
      // 2. Jump to the page (using the screen's controller)
      // Small delay prevents animation stutter
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _pageController.jumpToPage(index);
        }
      });
    } else {
      // Error: Keep dialog open and show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hymn #$numberStr not found."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  // --- COPY LOGIC ---
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

  String _formatForClipboard(String content) {
    if (!content.contains("<")) return content;
    String processed = content;
    processed = processed.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    processed = processed.replaceAll(RegExp(r'</(p|div)>', caseSensitive: false), '\n\n');
    processed = processed.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true), '');
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return processed.trim();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(hymnFontSizeProvider);
    final isKeepScreenOn = ref.watch(keepScreenOnProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : const Color(0xFF7D2D3B);

    final currentHymn = widget.allHymns[_currentIndex];
    
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
      
      // ✅ FLOATING SEARCH BUTTON
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: showMidi ? 90.0 : 0),
        child: FloatingActionButton(
          onPressed: _showHymnSearchDialog,
          backgroundColor: const Color(0xFF7D2D3B),
          elevation: 4,
          child: const Icon(Icons.search, color: Colors.white, size: 28),
        ),
      ),

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
      bottomNavigationBar: showMidi 
        ? HymnMidiPlayer(
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

          isHtml
              ? _buildHtmlContent(hymn.htmlContent, fontSize, isDark)
              : _buildPlainContent(hymn.htmlContent, fontSize, isDark),

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