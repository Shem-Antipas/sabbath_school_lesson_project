import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import 'lesson_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? hoveredIndex; // Track which card is being hovered

  @override
  Widget build(BuildContext context) {
    final asyncQuarterlies = ref.watch(quarterlyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sabbath School"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: asyncQuarterlies.when(
            data: (quarterlies) {
              return GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 30),
                // DYNAMIC COLUMNS: maxCrossAxisExtent ensures responsiveness
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  crossAxisSpacing: 25,
                  mainAxisSpacing: 25,
                  childAspectRatio: 0.68,
                ),
                itemCount: quarterlies.length,
                itemBuilder: (context, index) {
                  final item = quarterlies[index];
                  final isHovered = hoveredIndex == index;

                  final String proxiedImageUrl =
                      "http://127.0.0.1:8787/proxy-image?url=${Uri.encodeComponent(item.coverUrl)}";

                  return MouseRegion(
                    onEnter: (_) => setState(() => hoveredIndex = index),
                    onExit: (_) => setState(() => hoveredIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonListScreen(
                              quarterlyId: item.id,
                              quarterlyTitle: item.title,
                            ),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        // Scales up by 3% when hovered
                        transform: isHovered
                            ? (Matrix4.identity()..scale(1.03))
                            : Matrix4.identity(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // IMAGE SECTION
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isHovered
                                          ? Colors.black.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: isHovered ? 20 : 10,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: proxiedImageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.book,
                                            size: 40,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            // TEXT SECTION
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 15, 4, 0),
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: isHovered
                                      ? Colors.blueAccent
                                      : Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              child: Text(
                                item.humanDate,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            error: (err, stack) => Center(child: Text('Error: $err')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
