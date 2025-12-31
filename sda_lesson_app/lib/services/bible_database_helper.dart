import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BibleDatabaseHelper {
  static final BibleDatabaseHelper _instance = BibleDatabaseHelper._internal();
  factory BibleDatabaseHelper() => _instance;
  BibleDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "bible.db");

    // Check if DB exists. If not, copy it from assets.
    final exists = await databaseExists(path);

    if (!exists) {
      print("Creating new copy of Bible Database from assets");
      try {
        await Directory(dirname(path)).create(recursive: true);

        // Copy from assets
        ByteData data = await rootBundle.load(join("assets", "bible.db"));
        List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        print("Error copying database: $e");
      }
    } else {
      print("Opening existing Bible Database");
    }

    return await openDatabase(path, readOnly: true);
  }
}
