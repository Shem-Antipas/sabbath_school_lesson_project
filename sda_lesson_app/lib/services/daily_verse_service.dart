class DailyVerse {
  final String text;
  final String reference;

  DailyVerse({required this.text, required this.reference});
}

class DailyVerseService {
  static final List<DailyVerse> _verses = [
    DailyVerse(
      text:
          "For I know the thoughts that I think toward you, saith the LORD...",
      reference: "Jeremiah 29:11",
    ),
    DailyVerse(
      text: "But they that wait upon the LORD shall renew their strength...",
      reference: "Isaiah 40:31",
    ),
    DailyVerse(
      text: "I can do all things through Christ which strengtheneth me.",
      reference: "Philippians 4:13",
    ),
    DailyVerse(
      text: "The LORD is my shepherd; I shall not want.",
      reference: "Psalm 23:1",
    ),
    // Add as many as you like!
  ];

  static DailyVerse getTodayVerse() {
    int dayOfYear = DateTime.now().day + (DateTime.now().month * 31);
    return _verses[dayOfYear % _verses.length];
  }
}
