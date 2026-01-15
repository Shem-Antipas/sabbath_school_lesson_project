import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Required for Auth check

// --- SERVICES & PROVIDERS ---
import '../services/daily_verse_service.dart';
import '../services/greeting_service.dart';
import '../providers/data_providers.dart';

// --- SCREENS ---
import 'hymnal_screen.dart';
import 'settings_screen.dart';
import 'bible_screen.dart';
import 'egw_library_screen.dart';
import 'home_screen.dart';
import 'lesson_list_screen.dart';
import 'login_screen.dart';   // Ensure this file exists and class is named LoginScreen
import 'profile_screen.dart'; // Ensure this file exists and class is named ProfileScreen

// --- WIDGETS ---
import 'package:sda_lesson_app/widgets/simple_error_view.dart';
import 'package:sda_lesson_app/widgets/greeting_cards.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndShowNewYearPopup();
      if (mounted) {
        await _checkAndShowSabbathPopup();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // NEW YEAR POPUP LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _checkAndShowNewYearPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (now.month != 1) return;

    const String lastOpenDateKey = 'last_open_date';
    const String firstOpenTimeKey = 'first_open_timestamp';
    const String secondPopupShownKey = 'second_popup_shown';

    final String todayString = "${now.year}-${now.month}-${now.day}";
    final String? lastOpenDate = prefs.getString(lastOpenDateKey);

    bool shouldShowPopup = false;

    if (lastOpenDate != todayString) {
      shouldShowPopup = true;
      await prefs.setString(lastOpenDateKey, todayString);
      await prefs.setInt(firstOpenTimeKey, now.millisecondsSinceEpoch);
      await prefs.setBool(secondPopupShownKey, false);
    } else {
      final int? firstOpenTime = prefs.getInt(firstOpenTimeKey);
      final bool secondPopupShown = prefs.getBool(secondPopupShownKey) ?? false;

      if (firstOpenTime != null && !secondPopupShown) {
        final firstOpenDate = DateTime.fromMillisecondsSinceEpoch(
          firstOpenTime,
        );
        if (now.difference(firstOpenDate).inHours >= 3) {
          shouldShowPopup = true;
          await prefs.setBool(secondPopupShownKey, true);
        }
      }
    }

    if (shouldShowPopup && mounted) {
      _showNewYearDialog();
    }
  }

  void _showNewYearDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF06275C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.amber, size: 60),
            const SizedBox(height: 15),
            const Text(
              "Happy New Year!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "May this year bring you joy, success, and divine blessings as you study His word.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF06275C),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text("Amen"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SABBATH POPUP LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _checkAndShowSabbathPopup() async {
    final now = DateTime.now();

    bool isSabbath = false;
    if (now.weekday == DateTime.friday) {
      if (now.hour > 18 || (now.hour == 18 && now.minute >= 30)) {
        isSabbath = true;
      }
    } else if (now.weekday == DateTime.saturday) {
      if (now.hour < 18 || (now.hour == 18 && now.minute < 30)) {
        isSabbath = true;
      }
    }

    if (!isSabbath) return;

    final prefs = await SharedPreferences.getInstance();
    const String sabbathKey = 'sabbath_last_shown_time';
    final int? lastShownMillis = prefs.getInt(sabbathKey);

    bool shouldShow = false;

    if (lastShownMillis == null) {
      shouldShow = true;
    } else {
      final lastShownDate = DateTime.fromMillisecondsSinceEpoch(
        lastShownMillis,
      );
      final difference = now.difference(lastShownDate);

      if (difference.inHours >= 3) {
        shouldShow = true;
      }
    }

    if (shouldShow && mounted) {
      await prefs.setInt(sabbathKey, now.millisecondsSinceEpoch);
      _showSabbathDialog();
    }
  }

  void _showSabbathDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              margin: const EdgeInsets.only(top: 15, right: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFDAA520),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_twilight,
                    color: Color(0xFFDAA520),
                    size: 50,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Happy Sabbath!",
                    style: TextStyle(
                      color: Color(0xFF06275C),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif',
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Remember the Sabbath day, to keep it holy. May you find rest and peace in His presence.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Exodus 20:8",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 5),
                    ],
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILD METHODS
  // ---------------------------------------------------------------------------

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    final todayVerse = DailyVerseService.getTodayVerse();
    final asyncQuarterlies = ref.watch(quarterlyListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFFBFBFD);
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final avatarBg = isDark ? Colors.grey[800] : Colors.grey[200];

    final bool showSabbath = GreetingService.isSabbathTime();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: backgroundColor,
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _getGreeting(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: IconButton(
                  icon: Icon(Icons.settings, color: iconColor),
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
                child: InkWell(
                  // -----------------------------------------------------------
                  // ✅ UPDATED PROFILE LOGIC
                  // -----------------------------------------------------------
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // If Logged In -> Go to Profile
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    } else {
                      // If Logged Out -> Go to Login
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: CircleAvatar(
                    backgroundColor: avatarBg,
                    child: Icon(Icons.person_outline, color: iconColor),
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
                  // Optional Inline Sabbath Card
                  if (showSabbath) ...[
                    // const SabbathCard(), 
                    // const SizedBox(height: 20),
                  ],

                  _buildDailyVerseCard(todayVerse),

                  const SizedBox(height: 32),
                  const _SectionLabel(label: "Current Study"),
                  const SizedBox(height: 12),

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
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: SimpleErrorView(
                        onRetry: () => ref.refresh(quarterlyListProvider),
                      ),
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

  // --- WIDGET HELPERS ---

  Widget _buildDailyVerseCard(DailyVerse verse) {
    return GestureDetector(
      onTap: () {
        final parsed = parseBibleReference(verse.reference);
        if (parsed != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BibleScreen(
                initialBook: parsed['book'],
                initialChapter: parsed['chapter'],
                targetVerse: parsed['verse'], // Highlight this verse
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BibleScreen()),
          );
        }
      },
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.format_quote, color: Colors.white54, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        "Read Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildSabbathSchoolCard(
    BuildContext context,
    dynamic quarterly,
    bool isDark,
  ) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
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
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const HomeScreen()),
        ),
      },
      {
        'title': 'Bible',
        'img': 'assets/images/bible.png',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const BibleScreen()),
        ),
      },
      {
        'title': 'EGW',
        'img': 'assets/images/egw.png',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const EGWLibraryScreen()),
        ),
      },
      {
        'title': 'Sermons',
        'img': 'assets/images/sermons.png',
        'onTap': () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sermons Coming Soon!"))),
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

  Map<String, dynamic>? parseBibleReference(String reference) {
    try {
      int lastSpaceIndex = reference.lastIndexOf(' ');
      if (lastSpaceIndex == -1) return null;

      String book = reference.substring(0, lastSpaceIndex).trim();
      String location = reference.substring(lastSpaceIndex + 1).trim();

      List<String> parts = location.split(':');
      if (parts.length != 2) return null;

      return {
        'book': book,
        'chapter': int.parse(parts[0]),
        'verse': int.parse(parts[1]),
      };
    } catch (e) {
      debugPrint("Verse Parse Error: $e");
      return null;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]
        : Colors.grey[400];
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