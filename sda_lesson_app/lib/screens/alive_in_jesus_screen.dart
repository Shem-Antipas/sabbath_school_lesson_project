// File: lib/screens/alive_in_jesus_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/data_providers.dart';

// ✅ THIS IS THE CRITICAL LINE YOU WERE MISSING:
import 'alive_in_jesus_detail_screen.dart'; 

class AliveInJesusScreen extends ConsumerWidget {
  const AliveInJesusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(aliveInJesusListProvider);
    const primaryColor = Color(0xFF06275C); 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Alive in Jesus", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: primaryColor, 
          statusBarIconBrightness: Brightness.light, 
          statusBarBrightness: Brightness.dark, 
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (guides) {
          if (guides.isEmpty) return const Center(child: Text("No guides found."));
          
          final groupedData = _groupQuarterlies(guides);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: groupedData.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final guide = entry.value[index];
                      return _buildGridCard(context, guide);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Map<String, List<dynamic>> _groupQuarterlies(List<dynamic> allGuides) {
    final Map<String, List<dynamic>> groups = {
      'Babies': [], 'Beginner': [], 'Kindergarten': [], 'Primary': [], 'Resources': [] 
    };

    for (var guide in allGuides) {
      final title = (guide['title'] ?? '').toString().toLowerCase();
      final id = (guide['id'] ?? '').toString().toLowerCase();
      final group = (guide['group'] ?? guide['quarterly_group'] ?? '').toString().toLowerCase();

      if (id.contains('-bb') || title.contains('babies') || group.contains('babies')) {
        groups['Babies']!.add(guide);
      } else if (id.contains('-bg') || title.contains('beginner') || group.contains('beginner')) {
        groups['Beginner']!.add(guide);
      } else if (id.contains('-kd') || title.contains('kindergarten') || group.contains('kindergarten')) {
        groups['Kindergarten']!.add(guide);
      } else if (id.contains('-pr') || title.contains('primary') || group.contains('primary')) {
        groups['Primary']!.add(guide);
      } else {
        groups['Resources']!.add(guide);
      }
    }
    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  Widget _buildGridCard(BuildContext context, dynamic guide) {
    return GestureDetector(
      onTap: () {
        // ✅ NOW THIS WILL WORK because we imported the file above
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AliveInJesusDetailScreen(
              guideData: guide, 
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: guide['cover'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            guide['title'],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          Text(
            guide['human_date'] ?? guide['description'] ?? '',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}