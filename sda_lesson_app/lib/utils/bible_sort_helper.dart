// lib/utils/bible_sort_helper.dart

class BibleSortHelper {
  // ✅ KEYS NOW MATCH YOUR BibleApiService EXACTLY
  static const Map<String, int> _bookOrder = {
    // Old Testament
    'Gen': 1, 'Exod': 2, 'Lev': 3, 'Num': 4, 'Deut': 5,
    'Josh': 6, 'Judg': 7, 'Ruth': 8, '1Sam': 9, '2Sam': 10,
    '1Kgs': 11, '2Kgs': 12, '1Chr': 13, '2Chr': 14, 'Ezra': 15,
    'Neh': 16, 'Esth': 17, 'Job': 18, 'Ps': 19, 'Prov': 20,
    'Eccl': 21, 'Song': 22, 'Isa': 23, 'Jer': 24, 'Lam': 25,
    'Ezek': 26, 'Dan': 27, 'Hos': 28, 'Joel': 29, 'Amos': 30,
    'Obad': 31, 'Jonah': 32, 'Mic': 33, 'Nah': 34, 'Hab': 35,
    'Zeph': 36, 'Hag': 37, 'Zech': 38, 'Mal': 39,
    
    // New Testament
    'Matt': 40, 'Mark': 41, 'Luke': 42, 'John': 43, 'Acts': 44,
    'Rom': 45, '1Cor': 46, '2Cor': 47, 'Gal': 48, 'Eph': 49,
    'Phil': 50, 'Col': 51, '1Thess': 52, '2Thess': 53, '1Tim': 54,
    '2Tim': 55, 'Titus': 56, 'Phlm': 57, 'Heb': 58, 'Jas': 59,
    '1Pet': 60, '2Pet': 61, '1John': 62, '2John': 63, '3John': 64,
    'Jude': 65, 'Rev': 66,
  };

  static List<Map<String, dynamic>> sortResults(List<Map<String, dynamic>> results) {
    // Create a mutable copy
    final sortedList = List<Map<String, dynamic>>.from(results);

    sortedList.sort((a, b) {
      // 1. Sort by Book Order
      // Default to 999 if the ID isn't found (prevents crashes)
      final bookA = _bookOrder[a['bookId']] ?? 999;
      final bookB = _bookOrder[b['bookId']] ?? 999;
      
      if (bookA != bookB) return bookA.compareTo(bookB);

      // 2. Sort by Chapter
      final chapterA = int.tryParse(a['chapter'].toString()) ?? 0;
      final chapterB = int.tryParse(b['chapter'].toString()) ?? 0;

      if (chapterA != chapterB) return chapterA.compareTo(chapterB);

      // 3. Sort by Verse
      final verseA = int.tryParse(a['verseNum'].toString()) ?? 0;
      final verseB = int.tryParse(b['verseNum'].toString()) ?? 0;

      return verseA.compareTo(verseB);
    });

    return sortedList;
  }
}