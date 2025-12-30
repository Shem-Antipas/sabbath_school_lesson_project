import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hymnal_provider.dart';

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
    // Find the starting position of the selected hymn in the list
    _currentIndex = widget.allHymns.indexOf(widget.initialHymn);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(hymnFontSizeProvider);
    final isKeepScreenOn = ref.watch(keepScreenOnProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF7D2D3B)),
        // The title now updates dynamically based on the swiped page
        title: Text(
          "Hymn ${widget.allHymns[_currentIndex].id}",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
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
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showFontControl(context, ref),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.allHymns.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final hymn = widget.allHymns[index];
          return _buildHymnContent(hymn, fontSize);
        },
      ),
    );
  }

  // Your original UI logic moved into a helper method for the PageView
  Widget _buildHymnContent(Hymn hymn, double fontSize) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            hymn.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7D2D3B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hymn.topic,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
          const Divider(height: 40, thickness: 1, indent: 50, endIndent: 50),
          Text(
            hymn.lyrics,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.6,
              fontFamily: 'Serif',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  void _showFontControl(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentSize = ref.watch(hymnFontSizeProvider);
          return Container(
            padding: const EdgeInsets.all(25),
            height: 160,
            child: Column(
              children: [
                const Text(
                  "ADJUST TEXT SIZE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.format_size, size: 16, color: Colors.grey),
                    Expanded(
                      child: Slider(
                        activeColor: const Color(0xFF7D2D3B),
                        inactiveColor: Colors.grey[300],
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
