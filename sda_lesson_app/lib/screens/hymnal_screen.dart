import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hymnal_provider.dart';
import 'hymn_detail_screen.dart';

class HymnalScreen extends ConsumerWidget {
  const HymnalScreen({super.key});

  // Helper method to group hymns by topic
  Map<String, List<Hymn>> _groupHymns(List<Hymn> hymns) {
    Map<String, List<Hymn>> groups = {};
    for (var hymn in hymns) {
      if (!groups.containsKey(hymn.topic)) {
        groups[hymn.topic] = [];
      }
      groups[hymn.topic]!.add(hymn);
    }
    return groups;
  }

  // --- JUMP TO NUMBER DIALOG ---
  void _showJumpToDialog(
    BuildContext context,
    WidgetRef ref,
    List<Hymn> allHymns,
  ) {
    String input = "";

    // 1. Theme Logic for Dialog
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final displayColor = isDark ? Colors.white : const Color(0xFF7D2D3B);
    final btnBg = isDark ? Colors.grey[800] : Colors.grey[200];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Go to Hymn",
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // THE INPUT DISPLAY
                    Text(
                      input.isEmpty ? "---" : input,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: displayColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 280,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          String label = "";
                          if (index < 9) label = "${index + 1}";
                          if (index == 9) label = "C";
                          if (index == 10) label = "0";
                          if (index == 11) label = "GO";

                          final isGoBtn = label == "GO";

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: isGoBtn
                                  ? const Color(0xFF7D2D3B)
                                  : btnBg,
                              foregroundColor:
                                  isGoBtn ? Colors.white : textColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                if (label == "C") {
                                  input = "";
                                } else if (label == "GO") {
                                  if (input.isNotEmpty) {
                                    final target = allHymns.firstWhere(
                                      (h) => h.id.toString() == input,
                                      orElse: () => allHymns.first,
                                    );
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => HymnDetailScreen(
                                          initialHymn: target,
                                          allHymns: allHymns,
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  if (input.length < 3) input += label;
                                }
                              });
                            },
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch Providers
    final filteredHymnsAsync = ref.watch(filteredHymnsProvider);
    final currentLanguage = ref.watch(hymnLanguageProvider);

    // 2. Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2);
    const brandColor = Color(0xFF7D2D3B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: brandColor,
        elevation: 0,
        leading: const Icon(Icons.chevron_left, color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hymnal",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            // ✅ SHOW CURRENT LANGUAGE SUBTITLE
            Text(
              currentLanguage.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          // ✅ LANGUAGE SWITCHER ICON
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: PopupMenuButton<HymnLanguage>(
              tooltip: "Switch Language",
              offset: const Offset(0, 40), // Lowers the menu slightly
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (HymnLanguage lang) {
                ref.read(hymnLanguageProvider.notifier).state = lang;
              },
              // Instead of a simple icon, we use a 'child' to make a button
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Semi-transparent pill
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      currentLanguage.label.toUpperCase(), // e.g., "ENGLISH"
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  ],
                ),
              ),
              itemBuilder: (BuildContext context) {
                return HymnLanguage.values.map((HymnLanguage lang) {
                  return PopupMenuItem<HymnLanguage>(
                    value: lang,
                    child: Row(
                      children: [
                        Icon(
                          lang == currentLanguage
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: lang == currentLanguage
                              ? brandColor
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          lang.label,
                          style: TextStyle(
                            fontWeight: lang == currentLanguage 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ],
      ),
      body: filteredHymnsAsync.when(
        data: (hymns) => Column(
          children: [
            _buildHeader(context, ref, hymns, isDark),
            _buildCategoryTabs(ref, isDark),
            Expanded(child: _buildMainList(context, ref, hymns, isDark)),
            _buildMiniPlayer(ref, isDark),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<Hymn> hymns,
    bool isDark,
  ) {
    return Container(
      color: const Color(0xFF7D2D3B),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              onChanged: (val) =>
                  ref.read(hymnSearchProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: "Search title or number",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _showJumpToDialog(context, ref, hymns),
            icon: const Icon(Icons.dialpad, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(WidgetRef ref, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip(ref, "Numerical", isDark),
          _filterChip(ref, "Alphabet", isDark),
          _filterChip(ref, "Topics", isDark),
        ],
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String label, bool isDark) {
    final currentMode = ref.watch(hymnSortModeProvider);
    final isSelected = currentMode == label;

    final selectedBg = isDark ? Colors.grey[800] : const Color(0xFFEDE7E3);
    final textColor = isDark ? Colors.white : Colors.black;
    final unselectedColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return GestureDetector(
      onTap: () => ref.read(hymnSortModeProvider.notifier).state = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? textColor : unselectedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMainList(
    BuildContext context,
    WidgetRef ref,
    List<Hymn> hymns,
    bool isDark,
  ) {
    final sortMode = ref.watch(hymnSortModeProvider);

    if (sortMode != 'Topics') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: hymns.length,
        itemBuilder: (context, index) =>
            _buildHymnCard(context, hymns[index], hymns, isDark),
      );
    }

    final grouped = _groupHymns(hymns);
    final topics = grouped.keys.toList();

    return CustomScrollView(
      slivers: topics.map((topic) {
        final topicHymns = grouped[topic]!;
        return SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTopicHeaderDelegate(
                title: topic,
                isDark: isDark,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildHymnCard(
                    context,
                    topicHymns[index],
                    topicHymns,
                    isDark,
                  ),
                  childCount: topicHymns.length,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildHymnCard(
    BuildContext context,
    Hymn hymn,
    List<Hymn> allHymns,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.black;
    final avatarBg = isDark ? Colors.grey[800] : const Color(0xFFF7F4F2);
    final numberColor = isDark ? Colors.white : const Color(0xFF7D2D3B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarBg,
          child: Text(
            "${hymn.id}",
            style: TextStyle(
              color: numberColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          hymn.title,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        subtitle: Text(
          hymn.lyrics.split('\n').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: subtitleColor),
        ),
        trailing: const Icon(Icons.play_arrow_rounded, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HymnDetailScreen(initialHymn: hymn, allHymns: allHymns),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniPlayer(WidgetRef ref, bool isDark) {
    final audio = ref.watch(audioProvider);
    if (audio.currentHymn == null) return const SizedBox.shrink();

    final progress = audio.duration.inSeconds > 0
        ? audio.position.inSeconds / audio.duration.inSeconds
        : 0.0;

    final playerBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: playerBg,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF7D2D3B)),
            minHeight: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "#${audio.currentHymn!.id}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      audio.currentHymn!.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  audio.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                iconSize: 40,
                color: isDark ? Colors.white : const Color(0xFF333333),
                onPressed: () => ref.read(audioProvider.notifier).togglePlay(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyTopicHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final bool isDark;
  _StickyTopicHeaderDelegate({required this.title, required this.isDark});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 40,
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white70 : const Color(0xFF7D2D3B),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40;
  @override
  double get minExtent => 40;
  @override
  bool shouldRebuild(covariant _StickyTopicHeaderDelegate oldDelegate) =>
      oldDelegate.title != title || oldDelegate.isDark != isDark;
}