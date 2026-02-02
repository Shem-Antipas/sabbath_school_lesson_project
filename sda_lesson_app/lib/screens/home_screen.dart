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
  final Color royalBlue = const Color(0xFF142042);
  
  // --- SEARCH STATE ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncQuarterlies = ref.watch(quarterlyListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search lessons...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              )
            : const Text(
                "Sabbath School",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: royalBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = "";
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
            icon: Icon(_isSearching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: asyncQuarterlies.when(
        data: (quarterlies) {
          // --- 1. SEARCH FILTER ---
          var filteredList = quarterlies.where((q) {
            final title = q.title.toString().toLowerCase();
            return title.contains(_searchQuery);
          }).toList();

          // --- 2. AGGRESSIVE EXCLUSION (Hide Youth/Children) ---
          filteredList = filteredList.where((q) {
            final id = (q.id ?? "").toString().toLowerCase();
            final title = q.title.toString().toLowerCase();
            
            // REMOVED: final group = q.quarterlyGroup... (This was causing the error)

            // LIST OF KEYWORDS TO BAN FROM HOME SCREEN
            final bannedKeywords = [
              // Categories
              'beginner', 'babies', 'kindergarten', 'primary', 'junior', 
              'powerpoints', 'cornerstone', 'real time faith', 'rtf', 
              'alive in jesus', 'alive-in-jesus', 
              
              // Specific Titles seen in screenshots
              'yaq',               // "Student YAQ1" (Beginner)
              'colliding kingdoms', // Real Time Faith title
              'teacher guide'      // Often usually for children's lessons
            ];

            // 1. Check Keywords in ID and Title
            for (var k in bannedKeywords) {
              if (id.contains(k) || title.contains(k)) return false;
            }
            
            // 2. Check Specific ID Suffixes (Adventech Standard)
            // These usually denote children's lessons
            if (id.contains('-bg') || // Beginner
                id.contains('-kd') || // Kindergarten
                id.contains('-pr') || // Primary
                id.contains('-jr') || // Junior
                id.contains('-pp') || // PowerPoints
                id.contains('-rt') || // Real Time Faith
                id.contains('-cc'))   // Conerstone Connections
            {
               return false;
            }

            return true;
          }).toList();

          // --- 3. CATEGORIZATION LOGIC ---
          
          // A. Easy Reading (Explicitly marked)
          final easyReading = filteredList.where((q) {
             final t = q.title.toString().toLowerCase();
             final id = (q.id ?? "").toString().toLowerCase();
             return id.contains('er') || t.contains('easy reading');
          }).toList();

          // B. Inverse / Collegiate (Young Adult) - Keep on Home
          final inverse = filteredList.where((q) {
             final t = q.title.toString().toLowerCase();
             final id = (q.id ?? "").toString().toLowerCase();
             return id.contains('cq') || id.contains('in') || t.contains('inverse') || t.contains('collegiate');
          }).toList();

          // C. Standard Adult (Whatever is left)
          final adult = filteredList.where((q) {
            final t = q.title.toString().toLowerCase();
            final id = (q.id ?? "").toString().toLowerCase();
            
            bool isEasy = id.contains('er') || t.contains('easy reading');
            bool isInverse = id.contains('cq') || id.contains('in') || t.contains('inverse') || t.contains('collegiate');
            
            return !isEasy && !isInverse;
          }).toList();

          // --- 4. BUILD UI ---
          if (filteredList.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                   const SizedBox(height: 10),
                   const Text("No lessons found", style: TextStyle(color: Colors.grey)),
                 ],
               ),
             );
          }

          return ListView(
            padding: const EdgeInsets.only(top: 20, bottom: 50),
            children: [
              // Group 1: Standard Adult
              if (adult.isNotEmpty)
                _QuarterlySection(title: "Standard Adult", items: adult, seeAllColor: royalBlue),
              
              // Group 2: Easy Reading
              if (easyReading.isNotEmpty)
                _QuarterlySection(title: "Easy Reading", items: easyReading, seeAllColor: royalBlue),
              
              // Group 3: Inverse
              if (inverse.isNotEmpty)
                _QuarterlySection(title: "Inverse & Young Adult", items: inverse, seeAllColor: royalBlue),
            ],
          );
        },
        error: (err, stack) => Center(
          child: ConnectionErrorCard(onRetry: () => ref.refresh(quarterlyListProvider)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _QuarterlySection extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final Color seeAllColor;

  const _QuarterlySection({
    required this.title,
    required this.items,
    required this.seeAllColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.blue[200] : const Color(0xFF142042); 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                  letterSpacing: 1.0,
                ),
              ),
              if (items.length > 5)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => SectionViewScreen(
                        title: title, 
                        items: items,
                        appBarColor: seeAllColor,
                      ))
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        Text(
                          "See All",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : seeAllColor,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: isDark ? Colors.grey[400] : seeAllColor,
                        )
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
        SizedBox(
          height: 260, 
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: items.length > 5 ? 5 : items.length, 
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 160,
                child: QuarterlyCard(item: items[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class SectionViewScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final Color appBarColor;

  const SectionViewScreen({
    super.key,
    required this.title,
    required this.items,
    required this.appBarColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => QuarterlyCard(item: items[index]),
      ),
    );
  }
}

class QuarterlyCard extends StatelessWidget {
  final dynamic item; 

  const QuarterlyCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.1),
                     blurRadius: 8,
                     offset: const Offset(0, 4),
                   )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: item.fullCoverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: titleColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.humanDate,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}