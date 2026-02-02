import 'package:shared_preferences/shared_preferences.dart';

class DailyVerse {
  final String text;
  final String reference;

  const DailyVerse({required this.text, required this.reference});
}

class DailyVerseService {
  // --- 1. VERSE LIBRARY ---
  static final List<DailyVerse> _allVerses = [
    const DailyVerse(
      text: "Have I not commanded thee? Be strong and of a good courage.",
      reference: "Joshua 1:9",
    ),
    const DailyVerse(
      text: "In the beginning God created the heavens and the earth.",
      reference: "Genesis 1:1",
    ),
    const DailyVerse(
      text: "The Lord shall fight for you, and ye shall hold your peace.",
      reference: "Exodus 14:14",
    ),
    const DailyVerse(
      text: "The Lord bless thee, and keep thee.",
      reference: "Numbers 6:24",
    ),
    const DailyVerse(
      text: "Trust in the Lord with all thine heart; and lean not unto thine own understanding.",
      reference: "Proverbs 3:5",
    ),
    const DailyVerse(
      text: "Thy word is a lamp unto my feet, and a light unto my path.",
      reference: "Psalms 119:105",
    ),
    const DailyVerse(
      text: "The Lord is my shepherd; I shall not want.",
      reference: "Psalms 23:1",
    ),
    const DailyVerse(
      text: "A friend loveth at all times, and a brother is born for adversity.",
      reference: "Proverbs 17:17",
    ),
    const DailyVerse(
      text: "But they that wait upon the Lord shall renew their strength.",
      reference: "Isaiah 40:31",
    ),
    const DailyVerse(
      text: "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil.",
      reference: "Jeremiah 29:11",
    ),
    const DailyVerse(
      text: "The Lord is good, a strong hold in the day of trouble.",
      reference: "Nahum 1:7",
    ),
    const DailyVerse(
      text: "For God so loved the world, that he gave his only begotten Son.",
      reference: "John 3:16",
    ),
    const DailyVerse(
      text: "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
      reference: "Matthew 11:28",
    ),
    const DailyVerse(
      text: "I am the way, the truth, and the life: no man cometh unto the Father, but by me.",
      reference: "John 14:6",
    ),
    const DailyVerse(
      text: "I can do all things through Christ which strengtheneth me.",
      reference: "Philippians 4:13",
    ),
    const DailyVerse(
      text: "And we know that all things work together for good to them that love God.",
      reference: "Romans 8:28",
    ),
    const DailyVerse(
      text: "If we confess our sins, he is faithful and just to forgive us our sins.",
      reference: "1 John 1:9",
    ),
    const DailyVerse(
      text: "Be careful for nothing; but in everything by prayer and supplication with thanksgiving let your requests be made known unto God.",
      reference: "Philippians 4:6",
    ),
    const DailyVerse(
      text: "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God.",
      reference: "Ephesians 2:8",
    ),
    const DailyVerse(
      text: "Let the word of Christ dwell in you richly in all wisdom.",
      reference: "Colossians 3:16",
    ),
    const DailyVerse(
      text: "Behold, I stand at the door, and knock.",
      reference: "Revelation 3:20",
    ),
  ];

  // --- 2. SMART GETTER (Handles Date Checking Logic Here) ---
  static Future<DailyVerse> getTodayVerse() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Get current saved state
    String? lastDate = prefs.getString('verse_date');
    int currentIndex = prefs.getInt('verse_index') ?? 0;

    // 2. Get today's actual date
    final String todayString = DateTime.now().toIso8601String().split('T')[0];

    // 3. Compare: If the saved date is NOT today, update the verse index
    if (lastDate != todayString) {
      // Move to the next verse
      currentIndex = (currentIndex + 1) % _allVerses.length;

      // Save the new state
      await prefs.setInt('verse_index', currentIndex);
      await prefs.setString('verse_date', todayString);
    }

    // 4. Safety Check (In case list size shrinks in updates)
    if (currentIndex >= _allVerses.length) {
      currentIndex = 0;
      // Don't save 0 yet, just display it to be safe
    }

    return _allVerses[currentIndex];
  }

  // --- 3. PLACEHOLDER ---
  static DailyVerse getPlaceholderVerse() {
    return _allVerses[0];
  }
}