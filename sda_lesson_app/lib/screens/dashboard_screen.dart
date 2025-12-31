import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/daily_verse_service.dart';
import '../providers/data_providers.dart';
import 'hymnal_screen.dart';
import 'settings_screen.dart';
import 'bible_screen.dart';
import 'egw_library_screen.dart';
import 'home_screen.dart';
import 'lesson_list_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayVerse = DailyVerseService.getTodayVerse();
    final asyncQuarterlies = ref.watch(quarterlyListProvider);

    // 1. Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Dynamic Colors
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFFBFBFD);
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final avatarBg = isDark ? Colors.grey[800] : Colors.grey[200];

    return Scaffold(
      backgroundColor: backgroundColor, // Dynamic Background
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: backgroundColor, // Dynamic AppBar Bg
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _getGreeting(),
                style: TextStyle(
                  color: textColor, // Dynamic Text Color
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: iconColor,
                  ), // Dynamic Icon Color
                  tooltip: "Settings",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 20),
                child: CircleAvatar(
                  backgroundColor: avatarBg, // Dynamic Avatar Bg
                  child: Icon(
                    Icons.person_outline,
                    color: iconColor, // Dynamic Icon Color
                  ),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDailyVerseCard(todayVerse),

                  const SizedBox(height: 32),

                  const _SectionLabel(label: "Current Study"),
                  const SizedBox(height: 12),

                  // Real Data Logic
                  asyncQuarterlies.when(
                    data: (quarterlies) {
                      if (quarterlies.isEmpty) {
                        return Text(
                          "No lessons available.",
                          style: TextStyle(color: textColor),
                        );
                      }
                      final currentQuarterly = quarterlies.first;
                      return _buildSabbathSchoolCard(
                        context,
                        currentQuarterly,
                        isDark,
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => Text(
                      "Error loading study: $err",
                      style: TextStyle(color: textColor),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const _SectionLabel(label: "Quick Study"),
                  const SizedBox(height: 12),
                  _buildQuickStudyGrid(context),

                  const SizedBox(height: 32),

                  const _SectionLabel(label: "More Resources"),
                  const SizedBox(height: 12),
                  _buildHymnalTile(context),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyVerseCard(DailyVerse verse) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, color: Colors.white54, size: 32),
          Text(
            verse.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "- ${verse.reference}",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Updated to accept isDark flag
  Widget _buildSabbathSchoolCard(
    BuildContext context,
    dynamic quarterly,
    bool isDark,
  ) {
    final cardColor = isDark
        ? const Color(0xFF1E1E1E)
        : Colors.white; // Dynamic Card Bg
    final textColor = isDark
        ? Colors.white
        : Colors.black87; // Dynamic Text Color
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF7D2D3B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: NetworkImage(quarterly.fullCoverUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          quarterly.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textColor,
          ),
        ),
        subtitle: Text(
          quarterly.humanDate,
          style: TextStyle(color: subTextColor),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonListScreen(
                quarterlyId: quarterly.id,
                quarterlyTitle: quarterly.title,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStudyGrid(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Lesson',
        'img': 'assets/images/lesson.png',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const HomeScreen()),
          );
        },
      },
      {
        'title': 'Bible',
        'img': 'assets/images/bible.png',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const BibleScreen()),
          );
        },
      },
      {
        'title': 'EGW',
        'img': 'assets/images/egw.png',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const EGWLibraryScreen()),
          );
        },
      },
      {
        'title': 'Sermons',
        'img': 'assets/images/sermons.png',
        'onTap': () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Sermons Coming Soon!")));
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildImageTile(
          context,
          items[index]['title'],
          items[index]['img'],
          items[index]['onTap'],
        );
      },
    );
  }

  Widget _buildImageTile(
    BuildContext context,
    String title,
    String imagePath,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHymnalTile(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => const HymnalScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF7D2D3B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 16),
            Text(
              "SDA Hymnal",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Spacer(),
            Icon(Icons.play_circle_outline, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    // Dynamic text color for section labels
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]
        : Colors
              .grey[400]; // Keep light grey for both generally, or tweak if needed

    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: textColor,
        letterSpacing: 1.2,
      ),
    );
  }
}
