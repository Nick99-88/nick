import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ShortsCacheEntry {
  final String shortId;
  final String title;
  final String description;
  final String uploaderName;
  final String uploaderAvatar;
  final String thumbnailUrl;
  final String videoUrl;
  final int feedPosition;
  final int totalChunks;
  final int downloadedChunks;
  final String status; // pending, downloading, ready, error
  final String? localVideoPath;
  final String? localThumbPath;
  final int fileSize;
  final double duration;
  final String createdAt;

  ShortsCacheEntry({
    required this.shortId,
    required this.title,
    this.description = '',
    this.uploaderName = '',
    this.uploaderAvatar = '',
    this.thumbnailUrl = '',
    required this.videoUrl,
    this.feedPosition = 0,
    this.totalChunks = 0,
    this.downloadedChunks = 0,
    this.status = 'pending',
    this.localVideoPath,
    this.localThumbPath,
    this.fileSize = 0,
    this.duration = 0,
    required this.createdAt,
  });

  double get progress => totalChunks > 0 ? downloadedChunks / totalChunks : 0;
  bool get isReady => status == 'ready';
  bool get isDownloading => status == 'downloading';

  Map<String, dynamic> toMap() => {
    'short_id': shortId,
    'title': title,
    'description': description,
    'uploader_name': uploaderName,
    'uploader_avatar': uploaderAvatar,
    'thumbnail_url': thumbnailUrl,
    'video_url': videoUrl,
    'feed_position': feedPosition,
    'total_chunks': totalChunks,
    'downloaded_chunks': downloadedChunks,
    'status': status,
    'local_video_path': localVideoPath,
    'local_thumb_path': localThumbPath,
    'file_size': fileSize,
    'duration': duration,
    'created_at': createdAt,
  };

  factory ShortsCacheEntry.fromMap(Map<String, dynamic> m) => ShortsCacheEntry(
    shortId: m['short_id'] ?? '',
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    uploaderName: m['uploader_name'] ?? '',
    uploaderAvatar: m['uploader_avatar'] ?? '',
    thumbnailUrl: m['thumbnail_url'] ?? '',
    videoUrl: m['video_url'] ?? '',
    feedPosition: m['feed_position'] ?? 0,
    totalChunks: m['total_chunks'] ?? 0,
    downloadedChunks: m['downloaded_chunks'] ?? 0,
    status: m['status'] ?? 'pending',
    localVideoPath: m['local_video_path'],
    localThumbPath: m['local_thumb_path'],
    fileSize: m['file_size'] ?? 0,
    duration: (m['duration'] ?? 0).toDouble(),
    createdAt: m['created_at'] ?? '',
  );

  ShortsCacheEntry copyWith({
    int? totalChunks,
    int? downloadedChunks,
    String? status,
    String? localVideoPath,
    String? localThumbPath,
    int? fileSize,
  }) => ShortsCacheEntry(
    shortId: shortId,
    title: title,
    description: description,
    uploaderName: uploaderName,
    uploaderAvatar: uploaderAvatar,
    thumbnailUrl: thumbnailUrl,
    videoUrl: videoUrl,
    feedPosition: feedPosition,
    totalChunks: totalChunks ?? this.totalChunks,
    downloadedChunks: downloadedChunks ?? this.downloadedChunks,
    status: status ?? this.status,
    localVideoPath: localVideoPath ?? this.localVideoPath,
    localThumbPath: localThumbPath ?? this.localThumbPath,
    fileSize: fileSize ?? this.fileSize,
    duration: duration,
    createdAt: createdAt,
  );
}

class ShortsCacheDatabase {
  static final ShortsCacheDatabase instance = ShortsCacheDatabase._init();
  static Database? _database;

  ShortsCacheDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shorts_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shorts_cache (
        short_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        uploader_name TEXT DEFAULT '',
        uploader_avatar TEXT DEFAULT '',
        thumbnail_url TEXT DEFAULT '',
        video_url TEXT NOT NULL,
        feed_position INTEGER DEFAULT 0,
        total_chunks INTEGER DEFAULT 0,
        downloaded_chunks INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        local_video_path TEXT,
        local_thumb_path TEXT,
        file_size INTEGER DEFAULT 0,
        duration REAL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_shorts_status ON shorts_cache(status)');
    await db.execute('CREATE INDEX idx_shorts_position ON shorts_cache(feed_position)');
  }

  Future<void> insertOrUpdate(ShortsCacheEntry entry) async {
    final db = await database;
    await db.insert('shorts_cache', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ShortsCacheEntry?> get(String shortId) async {
    final db = await database;
    final results = await db.query('shorts_cache',
        where: 'short_id = ?', whereArgs: [shortId]);
    return results.isNotEmpty ? ShortsCacheEntry.fromMap(results.first) : null;
  }

  Future<List<ShortsCacheEntry>> getAll() async {
    final db = await database;
    final results = await db.query('shorts_cache', orderBy: 'feed_position ASC');
    return results.map((m) => ShortsCacheEntry.fromMap(m)).toList();
  }

  Future<List<ShortsCacheEntry>> getReady() async {
    final db = await database;
    final results = await db.query('shorts_cache',
        where: 'status = ?', whereArgs: ['ready'], orderBy: 'feed_position ASC');
    return results.map((m) => ShortsCacheEntry.fromMap(m)).toList();
  }

  Future<List<ShortsCacheEntry>> getDownloaded() async {
    final db = await database;
    final results = await db.query('shorts_cache',
        where: 'status IN (?, ?)', whereArgs: ['ready', 'downloading'],
        orderBy: 'feed_position ASC');
    return results.map((m) => ShortsCacheEntry.fromMap(m)).toList();
  }

  Future<void> updateProgress(String shortId, int downloadedChunks, int totalChunks) async {
    final db = await database;
    await db.update(
      'shorts_cache',
      {
        'downloaded_chunks': downloadedChunks,
        'total_chunks': totalChunks,
        'status': downloadedChunks >= totalChunks ? 'ready' : 'downloading',
      },
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> updateStatus(String shortId, String status) async {
    final db = await database;
    await db.update(
      'shorts_cache',
      {'status': status},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> updateLocalPaths(String shortId, String videoPath, String thumbPath) async {
    final db = await database;
    await db.update(
      'shorts_cache',
      {'local_video_path': videoPath, 'local_thumb_path': thumbPath},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> delete(String shortId) async {
    final db = await database;
    await db.delete('shorts_cache', where: 'short_id = ?', whereArgs: [shortId]);
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('shorts_cache');
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM shorts_cache');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteOldest(int count) async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM shorts_cache WHERE short_id IN (
        SELECT short_id FROM shorts_cache ORDER BY feed_position ASC LIMIT $count
      )
    ''');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
