import 'bible_database_helper.dart';

class BibleApiService {
  final _dbHelper = BibleDatabaseHelper();

  // --- 1. UPDATED MAPPING ---
  // Keys now match the specific abbreviations in your DB (e.g. 'Josh', '1Thess')
  static const Map<String, String> _bibleBooks = {
    // Old Testament
    'Gen': 'Genesis',
    'Exod': 'Exodus',
    'Lev': 'Leviticus',
    'Num': 'Numbers',
    'Deut': 'Deuteronomy',
    'Josh': 'Joshua', // CHANGED from 'Jos' to 'Josh' (per screenshot)
    'Judg': 'Judges',
    'Ruth': 'Ruth',
    '1Sam': '1 Samuel',
    '2Sam': '2 Samuel',
    '1Kgs': '1 Kings',
    '2Kgs': '2 Kings',
    '1Chr': '1 Chronicles',
    '2Chr': '2 Chronicles',
    'Ezra': 'Ezra',
    'Neh': 'Nehemiah',
    'Esth': 'Esther',
    'Job': 'Job',
    'Ps': 'Psalms',
    'Prov': 'Proverbs',
    'Eccl': 'Ecclesiastes',
    'Song': 'Song of Solomon',
    'Isa': 'Isaiah',
    'Jer': 'Jeremiah',
    'Lam': 'Lamentations',
    'Ezek': 'Ezekiel',
    'Dan': 'Daniel',
    'Hos': 'Hosea',
    'Joel': 'Joel',
    'Amos': 'Amos',
    'Obad': 'Obadiah',
    'Jonah': 'Jonah', // CHANGED from 'Jon' to 'Jonah' (per screenshot)
    'Mic': 'Micah',
    'Nah': 'Nahum',
    'Hab': 'Habakkuk',
    'Zeph': 'Zephaniah',
    'Hag': 'Haggai',
    'Zech': 'Zechariah',
    'Mal': 'Malachi',

    // New Testament
    'Matt': 'Matthew',
    'Mark': 'Mark',
    'Luke': 'Luke',
    'John': 'John',
    'Acts': 'Acts',
    'Rom': 'Romans',
    '1Cor': '1 Corinthians',
    '2Cor': '2 Corinthians',
    'Gal': 'Galatians',
    'Eph': 'Ephesians',
    'Phil': 'Philippians',
    'Col': 'Colossians',
    '1Thess':
        '1 Thessalonians', // CHANGED from '1Thes' to '1Thess' (per screenshot)
    '2Thess': '2 Thessalonians', // CHANGED from '2Thes' to '2Thess'
    '1Tim': '1 Timothy',
    '2Tim': '2 Timothy',
    'Titus': 'Titus',
    'Phlm': 'Philemon',
    'Heb': 'Hebrews',
    'Jas': 'James',
    '1Pet': '1 Peter',
    '2Pet': '2 Peter',
    '1John': '1 John',
    '2John': '2 John',
    '3John': '3 John',
    'Jude': 'Jude', // CHANGED from 'Jud' to 'Jude' (likely matches DB)
    'Rev': 'Revelation',
  };

  // --- 2. FETCH BOOKS ---
  Future<List<Map<String, dynamic>>> fetchBooks() async {
    final db = await _dbHelper.database;

    // Get all book abbreviations present in the DB
    final List<Map<String, dynamic>> rawMaps = await db.rawQuery(
      'SELECT DISTINCT book FROM bible',
    );

    // Create a Set for fast lookup
    final Set<String> dbBookKeys = rawMaps
        .map((m) => m['book'] as String)
        .toSet();

    List<Map<String, dynamic>> sortedList = [];

    // Iterate through OUR master list to enforce Chronological Order
    _bibleBooks.forEach((standardKey, fullName) {
      // Check if this book exists in the DB
      if (dbBookKeys.contains(standardKey)) {
        sortedList.add({
          'id': standardKey,
          'name': fullName,
          'nameLong': fullName,
          'abbreviation': standardKey,
        });
        dbBookKeys.remove(standardKey);
      }
    });

    // Add any remaining books (fallback for mismatched keys)
    // If you see books at the bottom of the list, their keys are falling here.
    for (var remainingKey in dbBookKeys) {
      sortedList.add({
        'id': remainingKey,
        'name': remainingKey,
        'nameLong': remainingKey,
        'abbreviation': remainingKey,
      });
    }

    return sortedList;
  }

  // --- 3. FETCH CHAPTERS ---
  Future<List<Map<String, dynamic>>> fetchChapters(String bookId) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT chapter FROM bible WHERE book = ? ORDER BY chapter ASC',
      [bookId],
    );

    return List.generate(result.length, (i) {
      final chapterNum = result[i]['chapter'].toString();
      final niceBookName = _bibleBooks[bookId] ?? bookId;

      return {
        'id': '$bookId.$chapterNum',
        'number': chapterNum,
        'reference': '$niceBookName $chapterNum',
      };
    });
  }

  // --- 4. FETCH VERSES (CLEAN TAGS) ---
  Future<List<Map<String, String>>> fetchChapterVerses(String chapterId) async {
    final int lastDotIndex = chapterId.lastIndexOf('.');
    if (lastDotIndex == -1) return [];

    final String bookName = chapterId.substring(0, lastDotIndex);
    final String chapterNum = chapterId.substring(lastDotIndex + 1);

    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      'bible',
      columns: ['verse', 'content'],
      where: 'book = ? AND chapter = ?',
      whereArgs: [bookName, chapterNum],
      orderBy: 'verse ASC',
    );

    return List.generate(maps.length, (i) {
      String rawContent = maps[i]['content'].toString();
      String cleanText = rawContent.replaceAll(RegExp(r'<[^>]*>'), '');

      return {'number': maps[i]['verse'].toString(), 'text': cleanText.trim()};
    });
  }

  // --- 5. SEARCH FUNCTION ---
  Future<List<Map<String, dynamic>>> searchBible(
    String query, {
    String? bookId,
  }) async {
    final db = await _dbHelper.database;

    String sql = "SELECT * FROM bible WHERE content LIKE ?";
    List<dynamic> args = ['%$query%'];

    if (bookId != null && bookId != 'ALL') {
      sql += " AND book = ?";
      args.add(bookId);
    }

    sql += " LIMIT 50";

    final List<Map<String, dynamic>> results = await db.rawQuery(sql, args);

    return results.map((row) {
      String rawContent = row['content'].toString();
      String cleanText = rawContent.replaceAll(RegExp(r'<[^>]*>'), '');

      final niceBookName = _bibleBooks[row['book']] ?? row['book'];

      return {
        'chapterId': "${row['book']}.${row['chapter']}",
        'verseNum': row['verse'],
        'reference': "$niceBookName ${row['chapter']}:${row['verse']}",
        'text': cleanText,
      };
    }).toList();
  }
}
