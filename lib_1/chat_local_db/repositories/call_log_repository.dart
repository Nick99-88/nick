import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/local_call_log.dart';

class CallLogRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<int> insertCallLog(LocalCallLog log) async {
    final db = await _db.database;
    if (log.callId.isNotEmpty) {
      final existing = await getCallLogByCallId(log.callId);
      if (existing != null) return existing.id!;
    }
    return await db.insert('calls', log.toMap());
  }

  Future<int> updateCallLog(LocalCallLog log) async {
    if (log.id == null) throw Exception('Cannot update call log with null ID');
    final db = await _db.database;
    return await db.update(
      'calls',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<LocalCallLog?> getCallLogById(int id) async {
    final db = await _db.database;
    final maps = await db.query('calls', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return LocalCallLog.fromMap(maps.first);
  }

  Future<LocalCallLog?> getCallLogByCallId(String callId) async {
    final db = await _db.database;
    final maps = await db.query('calls', where: 'call_id = ?', whereArgs: [callId]);
    if (maps.isEmpty) return null;
    return LocalCallLog.fromMap(maps.first);
  }

  Future<List<LocalCallLog>> getCallLogsByPeerUserId(
    String peerUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final maps = await db.query(
      'calls',
      where: 'peer_user_id = ?',
      whereArgs: [peerUserId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => LocalCallLog.fromMap(maps[i]));
  }

  Future<List<LocalCallLog>> getAllCallLogs({int limit = 100, int offset = 0}) async {
    final db = await _db.database;
    final maps = await db.query(
      'calls',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => LocalCallLog.fromMap(maps[i]));
  }

  Future<int> deleteCallLog(int id) async {
    final db = await _db.database;
    return await db.delete('calls', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearCallLogs() async {
    final db = await _db.database;
    return await db.delete('calls');
  }

  Future<int> getCallLogCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM calls');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getMissedCallCountByPeer(String peerUserId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM calls WHERE peer_user_id = ? AND call_state = ?',
      [peerUserId, 'missed'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertOrUpdateCallLog(LocalCallLog log) async {
    final db = await _db.database;
    if (log.callId.isEmpty) return await db.insert('calls', log.toMap());
    final existing = await getCallLogByCallId(log.callId);
    if (existing != null) {
      return await db.update(
        'calls',
        log.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
    return await db.insert('calls', log.toMap());
  }
}
