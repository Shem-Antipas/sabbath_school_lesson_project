import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';
import 'alive_in_jesus_detail_screen.dart';
import 'lesson_list_screen.dart';

class AliveInJesusScreen extends ConsumerWidget {
  const AliveInJesusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(quarterlyListProvider);
    const primaryColor = Color(0xFF142042); 

    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text("Youth & Children", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: primaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (allQuarterlies) {
          final groupedData = _groupChildrenAndYouth(allQuarterlies);

          if (groupedData.isEmpty) {
            return const Center(child: Text("No youth or children's guides found."));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: groupedData.entries.map((entry) {
              return _buildHorizontalSection(context, entry.key, entry.value, primaryColor);
            }).toList(),
          );
        },
      ),
    );
  }

  // --- 1. FILTERING LOGIC (Separated Cornerstone & RTF) ---
  Map<String, List<dynamic>> _groupChildrenAndYouth(List<dynamic> list) {
    // The keys define the order on the screen
    final Map<String, List<dynamic>> groups = {
      'Alive in Jesus': [],       
      'Cornerstone Connections': [], // ✅ Separated
      'Real Time Faith': [],         // ✅ Separated
      'Junior & PowerPoints': [], 
      'Primary': [],              
      'Kindergarten': [],         
      'Beginner & Babies': [],    
    };

    for (var item in list) {
      final title = (item.title ?? '').toString().toLowerCase();
      final id = (item.id ?? '').toString().toLowerCase();

      // 🚫 STRICT EXCLUSION: Skip Inverse / Collegiate / Adult
      if ((id.contains('cq') || title.contains('inverse') || title.contains('collegiate') || id.contains('in')) && 
          !title.contains('cornerstone')) { 
        continue; 
      }

      // --- MATCHING LOGIC ---

      // A. ALIVE IN JESUS
      if (title.contains('alive in jesus') || id.contains('alive-in-jesus')) {
        groups['Alive in Jesus']!.add(item);
      }
      
      // B. CORNERSTONE CONNECTIONS (Strict)
      else if (id.contains('cornerstone') || title.contains('cornerstone') || id.contains('-cc')) { 
        groups['Cornerstone Connections']!.add(item);
      }

      // C. REAL TIME FAITH (Strict)
      else if (id.contains('rtf') || title.contains('real time faith') || 
               title.contains('colliding kingdoms') || id.contains('-rt')) {
        groups['Real Time Faith']!.add(item);
      }
      
      // D. JUNIOR / POWERPOINTS
      else if (id.contains('junior') || title.contains('junior') || 
               id.contains('powerpoints') || title.contains('powerpoints') ||
               id.contains('-jr') || id.contains('-pp')) {
        groups['Junior & PowerPoints']!.add(item);
      }
      
      // E. PRIMARY
      else if (id.contains('primary') || title.contains('primary') || id.contains('-pr')) {
        groups['Primary']!.add(item);
      }
      
      // F. KINDERGARTEN
      else if (id.contains('kindergarten') || title.contains('kindergarten') || id.contains('-kd')) {
        groups['Kindergarten']!.add(item);
      }

      // G. BEGINNER & BABIES
      else if (id.contains('beginner') || title.contains('beginner') || 
               id.contains('babies') || title.contains('babies') ||
               title.contains('yaq') || 
               id.contains('-bg') || id.contains('-bb')) {
        groups['Beginner & Babies']!.add(item);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  // --- 2. HORIZONTAL SECTION (Netflix Style) ---
  Widget _buildHorizontalSection(BuildContext context, String title, List<dynamic> items, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => SectionViewScreen(
                      title: title, 
                      items: items,
                      appBarColor: primaryColor,
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
                          color: primaryColor.withOpacity(0.8),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: primaryColor.withOpacity(0.8),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        
        SizedBox(
          height: 240, 
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length > 6 ? 6 : items.length, 
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 140, 
                child: _buildCard(context, items[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // --- 3. CARD WIDGET ---
  Widget _buildCard(BuildContext context, dynamic guide) {
    final String imageUrl = guide.fullCoverUrl ?? guide.cover ?? ""; 
    
    return GestureDetector(
      onTap: () {
        final id = (guide.id ?? "").toString().toLowerCase();
        if (id.contains('alive-in-jesus')) {
           Navigator.push(context, MaterialPageRoute(builder: (_) => AliveInJesusDetailScreen(guideData: guide)));
        } else {
           Navigator.push(context, MaterialPageRoute(builder: (_) => LessonListScreen(quarterlyId: guide.id, quarterlyTitle: guide.title)));
        }
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
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl, 
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            guide.title ?? "", 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
          ),
          const SizedBox(height: 4),
          if (guide.humanDate != null)
             Text(
               guide.humanDate!,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
               style: TextStyle(color: Colors.grey[600], fontSize: 11),
             )
        ],
      ),
    );
  }
}

// --- 4. "SEE ALL" SCREEN ---
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final guide = items[index];
          final String imageUrl = guide.fullCoverUrl ?? guide.cover ?? "";
          
          return GestureDetector(
            onTap: () {
               final id = (guide.id ?? "").toString().toLowerCase();
               if (id.contains('alive-in-jesus')) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AliveInJesusDetailScreen(guideData: guide)));
               } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LessonListScreen(quarterlyId: guide.id, quarterlyTitle: guide.title)));
               }
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
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl, 
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    guide.title ?? "", 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}