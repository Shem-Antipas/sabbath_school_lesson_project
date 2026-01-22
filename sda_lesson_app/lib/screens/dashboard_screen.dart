import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// --- SERVICES & PROVIDERS ---
import '../services/daily_verse_service.dart';
import '../services/greeting_service.dart';
import '../providers/data_providers.dart';

// --- SCREENS ---
import 'hymnal_screen.dart';
import 'settings_screen.dart';
import 'bible_screen.dart';
import 'bible_reader_screen.dart';
import 'egw_library_screen.dart';
import 'home_screen.dart';
import 'lesson_list_screen.dart';
import 'login_screen.dart';   
import 'profile_screen.dart'; 
import 'devotionals_library_screen.dart';

// --- WIDGETS ---
import 'package:sda_lesson_app/widgets/simple_error_view.dart';

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
      // ✅ Refresh user with safety check
      _refreshUser();
    });
  }

  // ✅ CRASH-PROOF USER REFRESH
  Future<void> _refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (e) {
        // Ignore the specific Pigeon decode error if it happens
        debugPrint("User reload warning (ignored): $e");
      }
      if (mounted) setState(() {}); 
    }
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
  // GREETING LOGIC
  // ---------------------------------------------------------------------------
  String _getGreeting(User? user) {
    final hour = DateTime.now().hour;
    String timeGreeting;
    
    if (hour < 12) {
      timeGreeting = "Good Morning";
    } else if (hour < 17) {
      timeGreeting = "Good Afternoon";
    } else {
      timeGreeting = "Good Evening";
    }

    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      final firstName = user.displayName!.split(' ')[0];
      return "$timeGreeting, $firstName";
    }

    return timeGreeting;
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
            // -----------------------------------------------------------------
            // STREAM BUILDER
            // -----------------------------------------------------------------
            title: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.userChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _getGreeting(user), 
                    style: TextStyle(
                      color: textColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
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
                  // ONTAP NAVIGATION
                  // -----------------------------------------------------------
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ).then((_) {
                        _refreshUser();
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      ).then((_) {
                        _refreshUser();
                      });
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
                  if (showSabbath) ...[
                    // const SabbathCard(), 
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.format_quote, color: Colors.white54, size: 32),
              
              // ---------------------------------------------------------------
              // UPDATED VISIBLE BUTTON
              // ---------------------------------------------------------------
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleVerseNavigation(verse.reference),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 8
                    ), // Large touch target
                    decoration: BoxDecoration(
                      color: Colors.white, // High Contrast Background
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ]
                    ),
                    child: const Row(
                      children: [
                        Text(
                          "Read Now",
                          style: TextStyle(
                            color: Color(0xFF2C3E50), // Dark text for readability
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded, 
                          color: Color(0xFF2C3E50), 
                          size: 18
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ---------------------------------------------------------------
            ],
          ),
          const SizedBox(height: 16),
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

  // ---------------------------------------------------------------------------
  // NEW HELPER: Handles navigation logic separately from UI
  // ---------------------------------------------------------------------------
  void _handleVerseNavigation(String reference) {
    debugPrint("Attempting to parse reference: $reference");
    
    final parsed = parseBibleReference(reference);
    
    if (parsed != null) {
      final String book = parsed['book'];
      final int chapter = parsed['chapter'];
      final int verse = parsed['verse']; //
      
      // 1. Generate the ID (e.g., "PSA.23") using the helper
      final String bookId = _getBookId(book); 
      final String chapterId = "$bookId.$chapter"; 
      
      // 2. Generate the Readable Reference (e.g., "Psalms 23")
      final String displayReference = "$book $chapter";

      debugPrint("Navigating to: $chapterId ($displayReference)");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BibleReaderScreen(
            // ✅ PASSING CORRECT NAMED ARGUMENTS
            chapterId: chapterId,
            reference: displayReference,
            targetVerse: verse,
          ),
        ),
      );
    } else {
      debugPrint("Parsing failed. Opening generic Bible Screen.");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BibleScreen()),
      );
    }
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
        'title': 'Devotionals',
        'img': 'assets/images/sermons.png',
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const DevotionalsLibraryScreen()),
        ),
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

  // ---------------------------------------------------------------------------
  // UPDATED PARSE LOGIC: Handles Ranges and Hyphens
  // ---------------------------------------------------------------------------
  Map<String, dynamic>? parseBibleReference(String reference) {
    try {
      final cleanRef = reference.trim();
      
      // Find separator between book name and numbers
      int lastSpaceIndex = cleanRef.lastIndexOf(' ');
      if (lastSpaceIndex == -1) return null;

      String book = cleanRef.substring(0, lastSpaceIndex).trim();
      String location = cleanRef.substring(lastSpaceIndex + 1).trim();

      if (book == "Psalm") {
        book = "Psalms";
      }

      // Ensure we have 'Chapter:Verse' format
      if (!location.contains(':')) return null;

      List<String> parts = location.split(':');
      
      // FIX: Handle verse ranges (e.g., "16-18") by taking only the first part
      String versePart = parts[1];
      if (versePart.contains('-')) {
        versePart = versePart.split('-')[0];
      }

      return {
        'book': book,
        'chapter': int.parse(parts[0]),
        'verse': int.parse(versePart),
      };
    } catch (e) {
      debugPrint("Verse Parse Error: $e");
      return null;
    }
  }
  String _getBookId(String bookName) {
    final map = {
      'Genesis': 'GEN', 'Exodus': 'EXO', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
      'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1 Samuel': '1SA', '2 Samuel': '2SA',
      '1 Kings': '1KI', '2 Kings': '2KI', '1 Chronicles': '1CH', '2 Chronicles': '2CH',
      'Ezra': 'EZR', 'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB', 'Psalms': 'Ps',
      'Psalm': 'Ps',   
      'Proverbs': 'PRO', 'Ecclesiastes': 'ECC', 'Song of Solomon': 'SNG', 'Isaiah': 'ISA',
      'Jeremiah': 'JER', 'Lamentations': 'LAM', 'Ezekiel': 'EZK', 'Daniel': 'DAN',
      'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO', 'Obadiah': 'OBA', 'Jonah': 'JON',
      'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB', 'Zephaniah': 'ZEP',
      'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL',
      'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
      'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL',
      'Ephesians': 'EPH', 'Philippians': 'PHP', 'Colossians': 'COL',
      '1 Thessalonians': '1TH', '2 Thessalonians': '2TH', '1 Timothy': '1TI',
      '2 Timothy': '2TI', 'Titus': 'TIT', 'Philemon': 'PHM', 'Hebrews': 'HEB',
      'James': 'JAS', '1 Peter': '1PE', '2 Peter': '2PE', '1 John': '1JN',
      '2 John': '2JN', '3 John': '3JN', 'Jude': 'JUD', 'Revelation': 'REV'
    };
    // Default to first 3 letters uppercase if not found
    return map[bookName] ?? bookName.substring(0, 3).toUpperCase();
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