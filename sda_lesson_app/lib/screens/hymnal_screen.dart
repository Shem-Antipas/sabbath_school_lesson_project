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
  // --- FULL JUMP TO NUMBER DIALOG ---
  void _showJumpToDialog(
    BuildContext context,
    WidgetRef ref,
    List<Hymn> allHymns,
  ) {
    String input = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Go to Hymn", textAlign: TextAlign.center),
              content: SizedBox(
                // Give the dialog content a fixed width to prevent layout recalculation
                width: MediaQuery.of(context).size.width * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize
                      .min, // Tell the column to be as small as possible
                  children: [
                    Text(
                      input.isEmpty ? "---" : input,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7D2D3B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Constrain the GridView height so it doesn't return "no size"
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
                              childAspectRatio:
                                  1.3, // Makes the buttons slightly wider
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          String label = "";
                          if (index < 9) label = "${index + 1}";
                          if (index == 9) label = "C";
                          if (index == 10) label = "0";
                          if (index == 11) label = "GO";

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: label == "GO"
                                  ? const Color(0xFF7D2D3B)
                                  : Colors.grey[200],
                              foregroundColor: label == "GO"
                                  ? Colors.white
                                  : Colors.black,
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
    final filteredHymnsAsync = ref.watch(filteredHymnsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7D2D3B),
        elevation: 0,
        title: const Text("Hymnal", style: TextStyle(color: Colors.white)),
        leading: const Icon(Icons.chevron_left, color: Colors.white),
      ),
      body: filteredHymnsAsync.when(
        data: (hymns) => Column(
          children: [
            _buildHeader(context, ref, hymns),
            _buildCategoryTabs(ref),
            Expanded(child: _buildMainList(context, ref, hymns)),
            _buildMiniPlayer(ref),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<Hymn> hymns) {
    return Container(
      color: const Color(0xFF7D2D3B),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) =>
                  ref.read(hymnSearchProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: "Search title or number",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
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

  Widget _buildCategoryTabs(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip(ref, "Numerical"),
          _filterChip(ref, "Alphabet"),
          _filterChip(ref, "Topics"),
        ],
      ),
    );
  }

  Widget _filterChip(WidgetRef ref, String label) {
    final currentMode = ref.watch(hymnSortModeProvider);
    final isSelected = currentMode == label;
    return GestureDetector(
      onTap: () => ref.read(hymnSortModeProvider.notifier).state = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE7E3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildMainList(BuildContext context, WidgetRef ref, List<Hymn> hymns) {
    final sortMode = ref.watch(hymnSortModeProvider);

    if (sortMode != 'Topics') {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: hymns.length,
        itemBuilder: (context, index) =>
            _buildHymnCard(context, hymns[index], hymns),
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
              delegate: _StickyTopicHeaderDelegate(title: topic),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildHymnCard(context, topicHymns[index], topicHymns),
                  childCount: topicHymns.length,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildHymnCard(BuildContext context, Hymn hymn, List<Hymn> allHymns) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF7F4F2),
          child: Text(
            "${hymn.id}",
            style: const TextStyle(
              color: Color(0xFF7D2D3B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          hymn.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hymn.lyrics.split('\n').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

  Widget _buildMiniPlayer(WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    if (audio.currentHymn == null) return const SizedBox.shrink();

    final progress = audio.duration.inSeconds > 0
        ? audio.position.inSeconds / audio.duration.inSeconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7D2D3B)),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
                color: const Color(0xFF333333),
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
  _StickyTopicHeaderDelegate({required this.title});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 40,
      color: const Color(0xFFF7F4F2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF7D2D3B),
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
