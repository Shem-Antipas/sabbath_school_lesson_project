import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // ✅ Added for Date Logic

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
import 'donate_screen.dart'; // ✅ NEW: Import Donate Screen
import 'reader_screen.dart'; // ✅ NEW: Import Reader Screen (Ensure filename matches)

// --- WIDGETS ---
import 'package:sda_lesson_app/widgets/simple_error_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DailyVerse _todayVerse = DailyVerseService.getPlaceholderVerse();
  
  // ✅ 1. LOADING STATE (Replaces the dialog)
  bool _isLessonLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _checkAndShowSabbathPopup();
      _refreshUser();
      await DailyVerseService.init();
      final verse = await DailyVerseService.getTodayVerse();
      if (mounted) setState(() => _todayVerse = verse);
    });
  }

  // ✅ 2. NAVIGATION LOGIC (Uses _isLessonLoading)
  Future<void> _handleIntelligentLessonNavigation(BuildContext context, dynamic quarterly) async {
    // Start Loading
    setState(() => _isLessonLoading = true);

    try {
      final lessons = await ref.read(lessonListProvider(quarterly.id).future);
      
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateFormat dateFormat = DateFormat("dd/MM/yyyy");

      dynamic matchedLesson;
      
      for (var lesson in lessons) {
        try {
          final DateTime start = dateFormat.parse(lesson.startDate);
          final DateTime end = dateFormat.parse(lesson.endDate);

          if ((today.isAtSameMomentAs(start) || today.isAfter(start)) &&
              (today.isAtSameMomentAs(end) || today.isBefore(end))) {
            matchedLesson = lesson;
            break;
          }
        } catch (e) {
          debugPrint("Date Parsing Error: $e");
        }
      }

      String? targetReadId;
      String? targetTitle;

      if (matchedLesson != null) {
        final DateTime lessonStart = dateFormat.parse(matchedLesson.startDate);
        final int dayDifference = today.difference(lessonStart).inDays;
        
        int dayIndex = dayDifference + 1;
        if (dayIndex < 1) dayIndex = 1;
        if (dayIndex > 7) dayIndex = 7;

        final String dayString = dayIndex.toString().padLeft(2, '0');
        
        // Clean URL Logic
        String cleanQId = quarterly.id.replaceAll('quarterlies/', '');
        if (!cleanQId.startsWith('en/')) cleanQId = "en/$cleanQId";

        String lessonIndex = matchedLesson.id;
        if (lessonIndex.contains('/')) {
          lessonIndex = lessonIndex.split('/').last;
        }

        targetReadId = "$cleanQId/$lessonIndex/$dayString";
        targetTitle = matchedLesson.title;
      }

      // Stop Loading BEFORE navigation
      if (mounted) setState(() => _isLessonLoading = false);

      if (context.mounted) {
        if (targetReadId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(
                lessonIndex: targetReadId!, 
                lessonTitle: targetTitle!,
              ),
            ),
          );
        } else {
          // Fallback to list
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonListScreen(
                quarterlyId: quarterly.id,
                quarterlyTitle: quarterly.title,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Nav Error: $e");
      if (mounted) setState(() => _isLessonLoading = false);
      
      // Fallback on error
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LessonListScreen(
              quarterlyId: quarterly.id,
              quarterlyTitle: quarterly.title,
            ),
          ),
        );
      }
    }
  }

  // Crash-proof user refresh
  Future<void> _refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (e) {
        debugPrint("User reload warning (ignored): $e");
      }
      if (mounted) setState(() {});
    }
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
                border: Border.all(color: const Color(0xFFDAA520), width: 2),
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
                  Icon(Icons.wb_twilight, color: Color(0xFFDAA520), size: 50),
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

    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      final firstName = user.displayName!.split(' ')[0];
      return "$timeGreeting, $firstName";
    }

    return timeGreeting;
  }

  @override
  Widget build(BuildContext context) {
    final todayVerse = _todayVerse;
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
                      // ✅ 3. USE THE SINGLE CORRECT BUILDER HERE
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

                  // ✅ NEW: DONATE CARD SECTION
                  const SizedBox(height: 24),
                  _buildDonateCard(context, isDark),

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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleVerseNavigation(verse.reference),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Text(
                          "Read Now",
                          style: TextStyle(
                            color: Color(0xFF2C3E50),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF2C3E50),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

  Widget _buildDonateCard(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.secondary;
    final textColor = colorScheme.onSurface;
    final subTextColor = textColor.withOpacity(0.6);
    final cardBg = isDark ? colorScheme.surfaceContainerHighest : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DONATE", 
            style: TextStyle(
              color: secondaryColor, 
              fontWeight: FontWeight.bold, 
              fontSize: 12, 
              letterSpacing: 1.5
            )
          ),
          const SizedBox(height: 10),
          Text(
            "Support the Ministry!",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Thanks to your donations, we’re able to keep developing and expanding what we offer.",
            style: TextStyle(
              color: subTextColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const DonateScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, 
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("DONATE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 4. SINGLE DEFINITION OF THIS CARD
  Widget _buildSabbathSchoolCard(BuildContext context, dynamic quarterly, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF7D2D3B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: NetworkImage(quarterly.fullCoverUrl), fit: BoxFit.cover),
          ),
        ),
        title: Text(quarterly.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        subtitle: Text(quarterly.humanDate, style: TextStyle(color: subTextColor)),
        
        // SWITCH ICON WITH SPINNER IF LOADING
        trailing: _isLessonLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            
        onTap: _isLessonLoading 
            ? null // Disable click while loading
            : () => _handleIntelligentLessonNavigation(context, quarterly),
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

  void _handleVerseNavigation(String reference) {
    debugPrint("Attempting to parse reference: $reference");

    final parsed = parseBibleReference(reference);

    if (parsed != null) {
      final String book = parsed['book'];
      final int chapter = parsed['chapter'];
      final int verse = parsed['verse'];

      final String bookId = _getBookId(book);
      final String chapterId = "$bookId.$chapter";
      final String displayReference = "$book $chapter";

      debugPrint("Navigating to: $chapterId ($displayReference)");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BibleReaderScreen(
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

  Map<String, dynamic>? parseBibleReference(String reference) {
    try {
      final cleanRef = reference.trim();
      int lastSpaceIndex = cleanRef.lastIndexOf(' ');
      if (lastSpaceIndex == -1) return null;

      String book = cleanRef.substring(0, lastSpaceIndex).trim();
      String location = cleanRef.substring(lastSpaceIndex + 1).trim();

      if (book == "Psalm") {
        book = "Psalms";
      }

      if (!location.contains(':')) return null;

      List<String> parts = location.split(':');
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
    final name = bookName.trim();

    final map = {
      'Genesis': 'GEN', 'Exodus': 'EXOD', 'Leviticus': 'LEV', 'Numbers': 'NUM', 'Deuteronomy': 'DEU',
      'Joshua': 'JOS', 'Judges': 'JDG', 'Ruth': 'RUT', '1 Samuel': '1SA', '2 Samuel': '2SA',
      '1 Kings': '1KI', '2 Kings': '2KI', '1 Chronicles': '1CH', '2 Chronicles': '2CH',
      'Ezra': 'EZR', 'Nehemiah': 'NEH', 'Esther': 'EST', 'Job': 'JOB',
      'Psalms': 'PSA', 'Psalm': 'PSA', 'Proverbs': 'PRO', 'Ecclesiastes': 'ECC',
      'Song of Solomon': 'SNG', 'Isaiah': 'ISA', 'Jeremiah': 'JER', 'Lamentations': 'LAM',
      'Ezekiel': 'EZK', 'Daniel': 'DAN', 'Hosea': 'HOS', 'Joel': 'JOL', 'Amos': 'AMO',
      'Obadiah': 'OBA', 'Jonah': 'JON', 'Micah': 'MIC', 'Nahum': 'NAM', 'Habakkuk': 'HAB',
      'Zephaniah': 'ZEP', 'Haggai': 'HAG', 'Zechariah': 'ZEC', 'Malachi': 'MAL',
      'Matthew': 'MAT', 'Mark': 'MRK', 'Luke': 'LUK', 'John': 'JHN', 'Acts': 'ACT',
      'Romans': 'ROM', '1 Corinthians': '1CO', '2 Corinthians': '2CO', 'Galatians': 'GAL',
      'Ephesians': 'EPH', 'Philippians': 'PHI', 'Colossians': 'COL', '1 Thessalonians': '1TH',
      '2 Thessalonians': '2TH', '1 Timothy': '1TI', '2 Timothy': '2TI', 'Titus': 'TIT',
      'Philemon': 'PHM', 'Hebrews': 'HEB', 'James': 'JAS', '1 Peter': '1PE', '2 Peter': '2PE',
      '1 John': '1JN', '2 John': '2JN', '3 John': '3JN', 'Jude': 'JUD', 'Revelation': 'REV',
    };

    return map[name] ?? (name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase());
  }
}
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[400];
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