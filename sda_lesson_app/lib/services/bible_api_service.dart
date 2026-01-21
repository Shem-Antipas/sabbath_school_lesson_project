import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// --- 0. VERSION DEFINITIONS ---
enum BibleVersion {
  kjv('KJV (King James)', 'bible', ''), 
  luo('Dholuo', 'verses_luo', 'assets/bibles/luo.json'),
  swahili('Swahili', 'verses_swahili', 'assets/bibles/swahili.json'),
  niv('NIV (New Int. Version)', 'verses_niv', 'assets/bibles/niv.json'),
  nkjv('NKJV (New King James)', 'verses_nkjv', 'assets/bibles/nkjv.json'),
  asv('ASV (American Standard)', 'verses_asv', 'assets/bibles/asv.json'),
  nasb('NASB (New American Std)', 'verses_nasb', 'assets/bibles/nasb.json'),
  gdn('Good News Bible', 'verses_gdn', 'assets/bibles/gdn.json'),
  bsb('Berean Study Bible', 'verses_bsb', 'assets/bibles/bsb.json'),
  amp('Amplified Bible', 'verses_amp', 'assets/bibles/amp.json'),
  ylt('Young\'s Literal Trans.', 'verses_ylt', 'assets/bibles/ylt.json');

  final String label;
  final String tableName;
  final String assetPath;
  const BibleVersion(this.label, this.tableName, this.assetPath);
}

class BibleApiService {
  static final BibleApiService _instance = BibleApiService._internal();
  factory BibleApiService() => _instance;
  BibleApiService._internal();

  static Database? _database;

  // --- 1. ENGLISH MAPPING (Standard IDs) ---
  static const Map<String, String> _englishNames = {
    'Gen': 'Genesis', 'Exod': 'Exodus', 'Lev': 'Leviticus', 'Num': 'Numbers', 'Deut': 'Deuteronomy',
    'Josh': 'Joshua', 'Judg': 'Judges', 'Ruth': 'Ruth', '1Sam': '1 Samuel', '2Sam': '2 Samuel',
    '1Kgs': '1 Kings', '2Kgs': '2 Kings', '1Chr': '1 Chronicles', '2Chr': '2 Chronicles', 'Ezra': 'Ezra',
    'Neh': 'Nehemiah', 'Esth': 'Esther', 'Job': 'Job', 'Ps': 'Psalms', 'Prov': 'Proverbs',
    'Eccl': 'Ecclesiastes', 'Song': 'Song of Solomon', 'Isa': 'Isaiah', 'Jer': 'Jeremiah', 'Lam': 'Lamentations',
    'Ezek': 'Ezekiel', 'Dan': 'Daniel', 'Hos': 'Hosea', 'Joel': 'Joel', 'Amos': 'Amos', 'Obad': 'Obadiah',
    'Jonah': 'Jonah', 'Mic': 'Micah', 'Nah': 'Nahum', 'Hab': 'Habakkuk', 'Zeph': 'Zephaniah',
    'Hag': 'Haggai', 'Zech': 'Zechariah', 'Mal': 'Malachi',
    'Matt': 'Matthew', 'Mark': 'Mark', 'Luke': 'Luke', 'John': 'John', 'Acts': 'Acts',
    'Rom': 'Romans', '1Cor': '1 Corinthians', '2Cor': '2 Corinthians', 'Gal': 'Galatians', 'Eph': 'Ephesians',
    'Phil': 'Philippians', 'Col': 'Colossians', '1Thess': '1 Thessalonians', '2Thess': '2 Thessalonians',
    '1Tim': '1 Timothy', '2Tim': '2 Timothy', 'Titus': 'Titus', 'Phlm': 'Philemon', 'Heb': 'Hebrews',
    'Jas': 'James', '1Pet': '1 Peter', '2Pet': '2 Peter', '1John': '1 John', '2John': '2 John',
    '3John': '3 John', 'Jude': 'Jude', 'Rev': 'Revelation',
  };

  // --- 2. LUO MAPPING ---
  static const Map<String, String> _luoNames = {
    'Gen': 'Chakruok', 'Exod': 'Wuok', 'Lev': 'Tim Jo-Lawi', 'Num': 'Kwan', 'Deut': 'Rapar mar Chik',
    'Josh': 'Joshua', 'Judg': 'Jong\'ad Bura', 'Ruth': 'Ruth', '1Sam': '1 Samuel', '2Sam': '2 Samuel',
    '1Kgs': '1 Ruodhi', '2Kgs': '2 Ruodhi', '1Chr': '1 Weche mag Ndalo', '2Chr': '2 Weche mag Ndalo',
    'Ezra': 'Ezra', 'Neh': 'Nehemia', 'Esth': 'Esta', 'Job': 'Ayub', 'Ps': 'Zaburi', 'Prov': 'Ngeche',
    'Eccl': 'Eklesiastes', 'Song': 'Wer Mamit', 'Isa': 'Isaya', 'Jer': 'Jeremia', 'Lam': 'Ywagruok',
    'Ezek': 'Ezekiel', 'Dan': 'Daniel', 'Hos': 'Hosea', 'Joel': 'Joel', 'Amos': 'Amos', 'Obad': 'Obadia',
    'Jonah': 'Jona', 'Mic': 'Mika', 'Nah': 'Nahum', 'Hab': 'Habakuk', 'Zeph': 'Zefania', 'Hag': 'Hagai',
    'Zech': 'Zekaria', 'Mal': 'Malaki', 'Matt': 'Mathayo', 'Mark': 'Mariko', 'Luke': 'Luka',
    'John': 'Johana', 'Acts': 'Tich Joote', 'Rom': 'Jo-Rumi', '1Cor': '1 Jo-Korintho', '2Cor': '2 Jo-Korintho',
    'Gal': 'Jo-Galatia', 'Eph': 'Jo-Efeso', 'Phil': 'Jo-Filipi', 'Col': 'Jo-Kolosai', '1Thess': '1 Jo-Thesalonika',
    '2Thess': '2 Jo-Thesalonika', '1Tim': '1 Timotheo', '2Tim': '2 Timotheo', 'Titus': 'Tito',
    'Phlm': 'Filemon', 'Heb': 'Jo-Hibrania', 'Jas': 'Jakobo', '1Pet': '1 Petro', '2Pet': '2 Petro',
    '1John': '1 Johana', '2John': '2 Johana', '3John': '3 Johana', 'Jude': 'Juda', 'Rev': 'Fweny',
  };

  // --- 3. SWAHILI MAPPING ---
  static const Map<String, String> _swahiliNames = {
    'Gen': 'Mwanzo', 'Exod': 'Kutoka', 'Lev': 'Mambo ya Walawi', 'Num': 'Hesabu', 'Deut': 'Kumbukumbu',
    'Josh': 'Yoshua', 'Judg': 'Waamuzi', 'Ruth': 'Ruthu', '1Sam': '1 Samweli', '2Sam': '2 Samweli',
    '1Kgs': '1 Wafalme', '2Kgs': '2 Wafalme', '1Chr': '1 Mambo ya Nyakati', '2Chr': '2 Mambo ya Nyakati',
    'Ezra': 'Ezra', 'Neh': 'Nehemia', 'Esth': 'Esta', 'Job': 'Ayubu', 'Ps': 'Zaburi', 'Prov': 'Mithali',
    'Eccl': 'Mhubiri', 'Song': 'Wimbo Ulio Bora', 'Isa': 'Isaya', 'Jer': 'Yeremia', 'Lam': 'Maombolezo',
    'Ezek': 'Ezekieli', 'Dan': 'Danieli', 'Hos': 'Hosea', 'Joel': 'Yoeli', 'Amos': 'Amosi',
    'Obad': 'Obadia', 'Jonah': 'Yona', 'Mic': 'Mika', 'Nah': 'Nahumu', 'Hab': 'Habakuki',
    'Zeph': 'Sefania', 'Hag': 'Hagai', 'Zech': 'Zekaria', 'Mal': 'Malaki', 'Matt': 'Mathayo',
    'Mark': 'Marko', 'Luke': 'Luka', 'John': 'Yohana', 'Acts': 'Matendo', 'Rom': 'Warumi',
    '1Cor': '1 Wakorintho', '2Cor': '2 Wakorintho', 'Gal': 'Wagalatia', 'Eph': 'Waefeso',
    'Phil': 'Wafilipi', 'Col': 'Wakolosai', '1Thess': '1 Wathesalonike', '2Thess': '2 Wathesalonike',
    '1Tim': '1 Timotheo', '2Tim': '2 Timotheo', 'Titus': 'Tito', 'Phlm': 'Filemoni', 'Heb': 'Waebrania',
    'Jas': 'Yakobo', '1Pet': '1 Petro', '2Pet': '2 Petro', '1John': '1 Yohana', '2John': '2 Yohana',
    '3John': '3 Yohana', 'Jude': 'Yuda', 'Rev': 'Ufunuo',
  };

  static const List<String> _bookIdsOrdered = [
    "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam",
    "1Kgs", "2Kgs", "1Chr", "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov",
    "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel", "Amos",
    "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal",
    "Matt", "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph",
    "Phil", "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus", "Phlm", "Heb",
    "Jas", "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev"
  ];

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "bible.db");
    
    // NOTE: In production, consider versioning to avoid needing to uninstall.
    final exists = await databaseExists(path);

    if (!exists) {
      print("Creating new copy of database from assets...");
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      ByteData data = await rootBundle.load("assets/bible.db");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      print("Database copied successfully!");
    }

    final db = await openDatabase(path, version: 1, readOnly: false);
    await _checkAndImportVersions(db);
    return db;
  }

  Future<void> _checkAndImportVersions(Database db) async {
    for (var version in BibleVersion.values) {
      if (version == BibleVersion.kjv) continue; 

      // 1. Create Table if Not Exists
      await db.execute(
        'CREATE TABLE IF NOT EXISTS ${version.tableName} (book TEXT, chapter INTEGER, verse INTEGER, content TEXT)'
      );

      // 2. CHECK IF DATA EXISTS (Row Count)
      // This is better than just checking if table exists, because a failed import might leave an empty table.
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM ${version.tableName}');
      final int count = Sqflite.firstIntValue(countResult) ?? 0;

      if (count == 0) {
        print("Importing ${version.label}...");
        try {
          final String jsonString = await rootBundle.loadString(version.assetPath);
          final dynamic decodedData = json.decode(jsonString);
          final batch = db.batch();

          // ✅ DETECT SWAHILI STRUCTURE (BIBLEBOOK -> List)
          if (decodedData is Map<String, dynamic> && 
              decodedData.containsKey('BIBLEBOOK') && 
              decodedData['BIBLEBOOK'] is List) {
            
            print("Detected Swahili List Structure for ${version.label}");
            _parseListStructure(decodedData, batch, version.tableName);
            
          } else if (decodedData is Map<String, dynamic>) {
            
            print("Detected Map Structure for ${version.label}");
            _parseMapStructure(decodedData, batch, version.tableName);
            
          } else {
             print("❌ Unknown JSON format for ${version.label}");
          }

          await batch.commit(noResult: true);
          print("✅ Imported ${version.label} successfully!");
        } catch (e) {
          print("❌ Error importing ${version.label}: $e");
        }
      }
    }
  }

  // --- PARSER: SWAHILI (List Structure - Robust Version) ---
  void _parseListStructure(Map<String, dynamic> data, Batch batch, String tableName) {
    // Safety check for root key
    if (!data.containsKey('BIBLEBOOK')) return;

    final List<dynamic> books = data['BIBLEBOOK'];

    for (var book in books) {
      // 1. Resolve Book ID from "book_number" (e.g. "1" -> "Gen")
      // Using tryParse is safer than parse.
      var bookNumRaw = book['book_number'];
      int bookNum = int.tryParse(bookNumRaw.toString()) ?? 0;
      
      // Safety check: Bible has 66 books.
      if (bookNum < 1 || bookNum > _bookIdsOrdered.length) {
        continue; 
      }
      
      String bookId = _bookIdsOrdered[bookNum - 1]; 

      // 2. Parse Chapters
      if (book['CHAPTER'] is! List) continue;
      final List<dynamic> chapters = book['CHAPTER'];

      for (var chapter in chapters) {
        var chapNumRaw = chapter['chapter_number'];
        // Remove non-digits just in case
        String cleanChap = chapNumRaw.toString().replaceAll(RegExp(r'[^0-9]'), '');
        int chapterNum = int.tryParse(cleanChap) ?? 0;
        
        if (chapterNum == 0) continue;

        // 3. Parse Verses
        if (chapter['VERSES'] is! List) continue;
        final List<dynamic> verses = chapter['VERSES'];

        for (var verse in verses) {
          var verseNumRaw = verse['verse_number'];
          var verseText = verse['verse_text'];
          
          String cleanVerse = verseNumRaw.toString().replaceAll(RegExp(r'[^0-9]'), '');
          int verseNum = int.tryParse(cleanVerse) ?? 0;

          if (verseNum > 0 && verseText != null) {
            batch.insert(tableName, {
              'book': bookId,
              'chapter': chapterNum,
              'verse': verseNum,
              'content': verseText.toString().trim()
            });
          }
        }
      }
    }
  }

  // --- PARSER: MAP STRUCTURE (With Safety Check for Isaiah/Jeremiah) ---
  void _parseMapStructure(Map<String, dynamic> rawData, Batch batch, String tableName) {
    rawData.forEach((bookKey, chaptersMap) {
      String bookId = bookKey; 

      // 1. Clean the book key
      String cleanKey = bookKey.trim().replaceAll('.', '').toLowerCase();

      // 2. SAFETY CHECK: Explicitly fix Isaya/Jeremia
      if (cleanKey == 'isaya' || cleanKey == 'isaiah') {
        bookId = 'Isa'; 
      } else if (cleanKey == 'jeremia' || cleanKey == 'jeremiah') {
        bookId = 'Jer'; 
      } else {
        var match = _englishNames.entries.firstWhere(
          (e) => e.value.toLowerCase() == cleanKey || e.key.toLowerCase() == cleanKey,
          orElse: () => const MapEntry('', ''),
        );

        if (match.key.isEmpty) {
          match = _luoNames.entries.firstWhere(
            (e) => e.value.toLowerCase() == cleanKey,
            orElse: () => const MapEntry('', ''),
          );
        }

        if (match.key.isEmpty) {
          match = _swahiliNames.entries.firstWhere(
            (e) => e.value.toLowerCase() == cleanKey,
            orElse: () => const MapEntry('', ''),
          );
        }

        if (match.key.isNotEmpty) {
          bookId = match.key;
        }
      }

      if (chaptersMap is Map) {
        chaptersMap.forEach((chapterNumStr, versesMap) {
          String cleanChapterStr = chapterNumStr.toString().replaceAll(RegExp(r'[^0-9]'), '');
          int chapter = int.tryParse(cleanChapterStr) ?? 0;
          
          if (versesMap is Map) {
            versesMap.forEach((verseNumStr, text) {
              String cleanVerseStr = verseNumStr.toString().replaceAll(RegExp(r'[^0-9]'), '');
              int verse = int.tryParse(cleanVerseStr) ?? 0;

              if (chapter > 0 && verse > 0) {
                batch.insert(tableName, {
                  'book': bookId, 
                  'chapter': chapter,
                  'verse': verse,
                  'content': text.toString().trim()
                });
              }
            });
          }
        });
      }
    });
  }

  // --- REST OF THE METHODS (Same as before) ---
  
  String _getStandardBookId(String inputName) {
    String cleanInput = inputName.trim().toLowerCase();
    
    var match = _englishNames.entries.firstWhere(
      (e) => e.key.toLowerCase() == cleanInput,
      orElse: () => const MapEntry('', ''),
    );
    if (match.key.isNotEmpty) return match.key;

    var luoMatch = _luoNames.entries.firstWhere(
      (e) => e.value.toLowerCase() == cleanInput,
      orElse: () => const MapEntry('', ''),
    );
    if (luoMatch.key.isNotEmpty) return luoMatch.key;

    var swahiliMatch = _swahiliNames.entries.firstWhere(
      (e) => e.value.toLowerCase() == cleanInput,
      orElse: () => const MapEntry('', ''),
    );
    if (swahiliMatch.key.isNotEmpty) return swahiliMatch.key;

    return inputName;
  }

  Future<List<Map<String, dynamic>>> fetchBooks({BibleVersion version = BibleVersion.kjv}) async {
    final db = await _db; 
    final List<Map<String, dynamic>> rawMaps = await db.rawQuery('SELECT DISTINCT book FROM bible');
    final Set<String> dbBookKeys = rawMaps.map((m) => m['book'] as String).toSet();
    List<Map<String, dynamic>> sortedList = [];

    Map<String, String> nameMap = _englishNames;
    if (version == BibleVersion.luo) nameMap = _luoNames;
    if (version == BibleVersion.swahili) nameMap = _swahiliNames;

    _englishNames.forEach((standardKey, defaultName) {
      if (dbBookKeys.contains(standardKey)) {
        String displayName = nameMap[standardKey] ?? defaultName;
        sortedList.add({
          'id': standardKey,
          'name': displayName, 
          'nameLong': displayName,
          'abbreviation': standardKey,
        });
        dbBookKeys.remove(standardKey);
      }
    });
    
    return sortedList;
  }

  Future<List<Map<String, dynamic>>> fetchChapters(String bookId) async {
    final db = await _db;
    String standardId = _getStandardBookId(bookId);

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT chapter FROM bible WHERE book = ? ORDER BY chapter ASC',
      [standardId],
    );

    return List.generate(result.length, (i) {
      final chapterNum = result[i]['chapter'].toString();
      return {
        'id': '$standardId.$chapterNum',
        'number': chapterNum,
        'reference': '$bookId $chapterNum', 
      };
    });
  }

  Future<List<Map<String, String>>> fetchChapterVerses(
    String chapterId, 
    {BibleVersion version = BibleVersion.kjv} 
  ) async {
    final int lastDotIndex = chapterId.lastIndexOf('.');
    if (lastDotIndex == -1) return [];

    String bookName = chapterId.substring(0, lastDotIndex);
    final String chapterNum = chapterId.substring(lastDotIndex + 1);

    bookName = _getStandardBookId(bookName);

    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      version.tableName,
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

 // --- SMART KEYWORD SEARCH ---
  Future<List<Map<String, dynamic>>> searchBible(
    String query, {
    String? bookId,
    BibleVersion version = BibleVersion.kjv,
  }) async {
    final db = await _db;
    
    // 1. Clean the input: Remove punctuation and extra spaces
    //    "Jesus, wept." -> "Jesus wept"
    String cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    if (cleanQuery.isEmpty) return [];

    // 2. Split into individual keywords
    //    "Jesus wept" -> ["Jesus", "wept"]
    List<String> keywords = cleanQuery.split(RegExp(r'\s+'));

    // 3. Build the SQL Query dynamically
    //    Start with basic SELECT
    StringBuffer sqlBuilder = StringBuffer("SELECT * FROM ${version.tableName} WHERE 1=1");
    List<dynamic> args = [];

    //    Add a "LIKE" condition for EACH keyword
    //    This means a verse must contain "Jesus" AND "wept" to show up.
    for (String word in keywords) {
      sqlBuilder.write(" AND content LIKE ?");
      args.add('%$word%');
    }

    // 4. Optional: Filter by Book
    if (bookId != null && bookId != 'ALL') {
      // Use the helper to ensure we search "Gen" instead of "Mwanzo"
      String standardId = _getStandardBookId(bookId);
      sqlBuilder.write(" AND book = ?");
      args.add(standardId);
    }

    // 5. Limit results to prevent crashing the UI with too many matches
    sqlBuilder.write(" LIMIT 100");

    final List<Map<String, dynamic>> results = await db.rawQuery(sqlBuilder.toString(), args);

    // 6. Map results for display
    Map<String, String> nameMap = _englishNames;
    if (version == BibleVersion.luo) nameMap = _luoNames;
    if (version == BibleVersion.swahili) nameMap = _swahiliNames;

    return results.map((row) {
      String rawContent = row['content'].toString();
      String cleanText = rawContent.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML/Tags if any
      
      final niceBookName = nameMap[row['book']] ?? row['book'];

      return {
        'chapterId': "${row['book']}.${row['chapter']}",
        'verseNum': row['verse'],
        'reference': "$niceBookName ${row['chapter']}:${row['verse']}",
        'text': cleanText,
      };
    }).toList();
  }
}