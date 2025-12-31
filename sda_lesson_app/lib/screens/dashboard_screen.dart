import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/daily_verse_service.dart';
import '../services/greeting_service.dart';
import '../providers/data_providers.dart';
import 'hymnal_screen.dart';
import 'settings_screen.dart';
import 'bible_screen.dart';
import 'egw_library_screen.dart';
import 'home_screen.dart';
import 'lesson_list_screen.dart';
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
      // Check New Year First
      await _checkAndShowNewYearPopup();

      // Check Sabbath Logic immediately after (if mounted)
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

    // Only run this check in January (Optional optimization)
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

    // 1. Check if it is currently Sabbath (Fri 6:30 PM - Sat 6:30 PM)
    bool isSabbath = false;
    if (now.weekday == DateTime.friday) {
      // Friday: After 18:30 (6:30 PM)
      if (now.hour > 18 || (now.hour == 18 && now.minute >= 30)) {
        isSabbath = true;
      }
    } else if (now.weekday == DateTime.saturday) {
      // Saturday: Before 18:30 (6:30 PM)
      if (now.hour < 18 || (now.hour == 18 && now.minute < 30)) {
        isSabbath = true;
      }
    }

    if (!isSabbath) return;

    // 2. Check Storage for frequency logic
    final prefs = await SharedPreferences.getInstance();
    const String sabbathKey = 'sabbath_last_shown_time';
    final int? lastShownMillis = prefs.getInt(sabbathKey);

    bool shouldShow = false;

    if (lastShownMillis == null) {
      // First time ever opening in a Sabbath window
      shouldShow = true;
    } else {
      final lastShownDate = DateTime.fromMillisecondsSinceEpoch(
        lastShownMillis,
      );
      final difference = now.difference(lastShownDate);

      // Show if more than 3 hours have passed since the last popup
      if (difference.inHours >= 3) {
        shouldShow = true;
      }
    }

    if (shouldShow && mounted) {
      // Save the current time as the new "Last Shown"
      await prefs.setInt(sabbathKey, now.millisecondsSinceEpoch);
      _showSabbathDialog();
    }
  }

  void _showSabbathDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap Close
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor:
            Colors.transparent, // Transparent to handle Stack nicely
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // THE CARD CONTENT
            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                40,
                20,
                20,
              ), // Top padding for Close button
              margin: const EdgeInsets.only(
                top: 15,
                right: 15,
              ), // Margin for Close button overlap
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFDAA520),
                  width: 2,
                ), // Gold border
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_twilight,
                    color: Color(0xFFDAA520),
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Happy Sabbath!",
                    style: TextStyle(
                      color: Color(0xFF06275C),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif', // Adds a classic feel
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Remember the Sabbath day, to keep it holy. May you find rest and peace in His presence.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
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

            // THE CLOSE BUTTON (Top Right)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red, // Distinct close button color
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

    // Check if Sabbath for the INLINE card (optional, you can keep or remove)
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
                child: CircleAvatar(
                  backgroundColor: avatarBg,
                  child: Icon(Icons.person_outline, color: iconColor),
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
                  // INLINE CARD (Optional: Keep it if you want a permanent banner too)
                  if (showSabbath) const SabbathCard(),

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

  // --- WIDGET HELPERS (Identical to previous versions) ---

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
