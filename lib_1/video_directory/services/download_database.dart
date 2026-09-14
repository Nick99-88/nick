import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/video_models.dart';

class DownloadDatabase {
  static final DownloadDatabase instance = DownloadDatabase._init();
  static Database? _database;

  DownloadDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('starlight_downloads.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade, onConfigure: _onConfigure);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        video_id TEXT NOT NULL,
        title TEXT NOT NULL,
        uploader_name TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'video',
        quality TEXT,
        local_path TEXT NOT NULL,
        thumbnail_path TEXT NOT NULL DEFAULT '',
        file_size INTEGER DEFAULT 0,
        duration REAL DEFAULT 0,
        downloaded_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE downloads ADD COLUMN thumbnail_path TEXT NOT NULL DEFAULT \'\'');
    }
  }

  Future<int> insertDownload(Map<String, dynamic> entry) async {
    final db = await database;
    return await db.insert('downloads', entry, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final db = await database;
    return await db.query('downloads', orderBy: 'downloaded_at DESC');
  }

  Future<Map<String, dynamic>?> getDownloadById(String id) async {
    final db = await database;
    final results = await db.query('downloads', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> deleteDownload(String id) async {
    final db = await database;
    return await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isVideoDownloaded(String videoId, {String? quality}) async {
    final db = await database;
    final where = quality != null ? 'video_id = ? AND quality = ?' : 'video_id = ?';
    final args = quality != null ? [videoId, quality] : [videoId];
    final results = await db.query('downloads', where: where, whereArgs: args);
    return results.isNotEmpty;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
