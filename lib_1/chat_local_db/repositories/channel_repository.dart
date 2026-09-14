import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/local_channel.dart';

class ChannelRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<void> insertOrUpdateChannel(LocalChannel channel) async {
    final db = await _db.database;
    await db.insert(
      'channels',
      channel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> cacheChannelFromServer({
    required String channelId,
    required String name,
    required String description,
    required String createdBy,
    required bool isPublic,
    required List<String> memberUserIds,
    required int memberCount,
    required String createdAt,
    required String updatedAt,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'channels',
      {
        'channel_id': channelId,
        'name': name,
        'description': description,
        'created_by': createdBy,
        'is_public': isPublic ? 1 : 0,
        'member_user_ids': jsonEncode(memberUserIds),
        'member_count': memberCount,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'local_cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LocalChannel?> getChannelById(String channelId) async {
    final db = await _db.database;
    final result = await db.query(
      'channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return LocalChannel.fromMap(result.first);
  }

  Future<List<LocalChannel>> getAllChannels() async {
    final db = await _db.database;
    final result = await db.query(
      'channels',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return result.map((map) => LocalChannel.fromMap(map)).toList();
  }

  Future<List<LocalChannel>> getActiveChannels() async {
    final db = await _db.database;
    final result = await db.query(
      'channels',
      where: 'is_archived = 0',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return result.map((map) => LocalChannel.fromMap(map)).toList();
  }

  Future<List<LocalChannel>> getArchivedChannels() async {
    final db = await _db.database;
    final result = await db.query(
      'channels',
      where: 'is_archived = 1',
      orderBy: 'updated_at DESC',
    );
    return result.map((map) => LocalChannel.fromMap(map)).toList();
  }

  Future<void> updateLastMessage(
    String channelId,
    String message,
    String time,
    String type,
    String sender,
  ) async {
    final db = await _db.database;
    await db.update(
      'channels',
      {
        'last_message': message,
        'last_message_time': time,
        'last_message_type': type,
        'last_message_sender': sender,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
  }

  Future<void> incrementUnreadCount(String channelId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE channels SET unread_count = unread_count + 1 WHERE channel_id = ?',
      [channelId],
    );
  }

  Future<void> clearUnreadCount(String channelId) async {
    final db = await _db.database;
    await db.update(
      'channels',
      {'unread_count': 0},
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
  }

  Future<void> togglePin(String channelId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE channels SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END WHERE channel_id = ?',
      [channelId],
    );
  }

  Future<void> toggleMute(String channelId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE channels SET is_muted = CASE WHEN is_muted = 1 THEN 0 ELSE 1 END WHERE channel_id = ?',
      [channelId],
    );
  }

  Future<void> toggleArchive(String channelId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE channels SET is_archived = CASE WHEN is_archived = 1 THEN 0 ELSE 1 END WHERE channel_id = ?',
      [channelId],
    );
  }

  Future<void> deleteChannel(String channelId) async {
    final db = await _db.database;
    await db.delete(
      'channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
  }

  Future<int> getTotalUnreadCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT SUM(unread_count) as total FROM channels WHERE is_muted = 0');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> updateChannelInfo({
    required String channelId,
    String? name,
    String? description,
    String? memberUserIdsJson,
    int? memberCount,
  }) async {
    final db = await _db.database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'local_cached_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (memberUserIdsJson != null) updates['member_user_ids'] = memberUserIdsJson;
    if (memberCount != null) updates['member_count'] = memberCount;

    await db.update(
      'channels',
      updates,
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
  }
}
