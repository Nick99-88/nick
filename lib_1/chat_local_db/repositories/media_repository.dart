import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/models.dart';

class MediaRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<int> insertMediaCache(MediaInfo media) async {
    final db = await _db.database;
    return await db.insert(
      'media_cache',
      media.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MediaInfo?> getMediaByMessageId(int messageId) async {
    final db = await _db.database;
    final maps = await db.query(
      'media_cache',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    if (maps.isEmpty) return null;
    return MediaInfo.fromMap(maps.first);
  }

  Future<List<MediaInfo>> getMediaByFilePath(String filePath) async {
    final db = await _db.database;
    final maps = await db.query(
      'media_cache',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
    return List.generate(maps.length, (i) => MediaInfo.fromMap(maps[i]));
  }

  Future<List<MediaInfo>> getAllDownloadedMedia({String? fileType}) async {
    final db = await _db.database;
    String where = 'is_downloaded = 1';
    List<dynamic> whereArgs = [];

    if (fileType != null) {
      where += ' AND file_type = ?';
      whereArgs.add(fileType);
    }

    final maps = await db.query(
      'media_cache',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'last_accessed DESC',
    );
    return List.generate(maps.length, (i) => MediaInfo.fromMap(maps[i]));
  }

  Future<int> updateMediaDownloadStatus(int mediaId, bool isDownloaded, {double progress = 1.0}) async {
    final db = await _db.database;
    return await db.update(
      'media_cache',
      {
        'is_downloaded': isDownloaded ? 1 : 0,
        'download_progress': progress,
        'last_accessed': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> updateDownloadProgress(int mediaId, double progress) async {
    final db = await _db.database;
    return await db.update(
      'media_cache',
      {
        'download_progress': progress,
        'last_accessed': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> updateLastAccessed(int mediaId) async {
    final db = await _db.database;
    return await db.update(
      'media_cache',
      {'last_accessed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> deleteMediaCache(int mediaId) async {
    final db = await _db.database;
    return await db.delete(
      'media_cache',
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<int> deleteMediaCacheByMessageId(int messageId) async {
    final db = await _db.database;
    return await db.delete(
      'media_cache',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> getStorageUsage() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size_bytes) as total FROM media_cache WHERE is_downloaded = 1',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<MediaInfo>> getOldMedia({int daysOld = 30}) async {
    final db = await _db.database;
    final maps = await db.query(
      'media_cache',
      where: 'is_downloaded = 1 AND last_accessed < date(\'now\', \'-$daysOld days\')',
      orderBy: 'last_accessed ASC',
    );
    return List.generate(maps.length, (i) => MediaInfo.fromMap(maps[i]));
  }

  Future<int> clearOldMedia({int daysOld = 30}) async {
    final db = await _db.database;
    return await db.delete(
      'media_cache',
      where: 'is_downloaded = 1 AND last_accessed < date(\'now\', \'-$daysOld days\')',
    );
  }

  Future<void> deleteAllMediaCache() async {
    final db = await _db.database;
    await db.delete('media_cache');
  }
}
