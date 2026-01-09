import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import 'lesson_list_screen.dart';
import 'package:sda_lesson_app/widgets/connection_error_card.dart'; 

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

    // 1. THEME DETECTION
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. DYNAMIC COLORS
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF121212) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.5)
        : Colors.black.withOpacity(0.1);
    final hoverShadowColor = isDark
        ? Colors.black.withOpacity(0.8)
        : Colors.black.withOpacity(0.2);

    return Scaffold(
      backgroundColor: backgroundColor, 
      appBar: AppBar(
        // --- REMOVED: No Leading Icon (Back Button) ---
        // This is now a top-level tab, so no back button is needed.
        title: Text(
          "Sabbath School",
          style: TextStyle(color: titleColor), 
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarColor, 
        iconTheme: IconThemeData(color: titleColor),
        automaticallyImplyLeading: false, // Ensures no automatic back button appears
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: asyncQuarterlies.when(
            data: (quarterlies) {
              return GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 30),
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

                  final String imageUrl = item.fullCoverUrl;

                  return MouseRegion(
                    onEnter: (_) => setState(() => hoveredIndex = index),
                    onExit: (_) => setState(() => hoveredIndex = null),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        // Keep PUSH here because LessonListScreen is a sub-page
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
                                          ? hoverShadowColor
                                          : shadowColor, 
                                      blurRadius: isHovered ? 20 : 10,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: isDark
                                              ? Colors.grey[800]
                                              : Colors.grey[300],
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 40,
                                            color: isDark
                                                ? Colors.grey[600]
                                                : Colors.grey,
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
                                      : titleColor, 
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              child: Text(
                                item.humanDate,
                                style: TextStyle(
                                  color: subtitleColor, 
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

            // 2. UPDATED ERROR LOGIC
            error: (err, stack) => ConnectionErrorCard(
              onRetry: () {
                ref.refresh(quarterlyListProvider);
              },
            ),

            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}