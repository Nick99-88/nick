import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/models.dart';

class MessageRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<int> insertMessage(LocalMessage message) async {
    final db = await _db.database;
    return await db.insert('messages', message.toMap());
  }

  Future<List<int>> insertMessagesBatch(List<LocalMessage> messages) async {
    final db = await _db.database;
    return await db.transaction((txn) async {
      final ids = <int>[];
      for (final message in messages) {
        final id = await txn.insert('messages', message.toMap());
        ids.add(id);
      }
      return ids;
    });
  }

  Future<LocalMessage?> getMessageById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return LocalMessage.fromMap(maps.first);
  }

  Future<List<LocalMessage>> getMessagesByPhone(
    String phoneNumber, {
    int limit = 100,
    int offset = 0,
    String? messageType,
    String? direction,
  }) async {
    final db = await _db.database;
    String where = 'chat_phone_number = ? AND is_deleted = 0 AND delete_for_me = 0';
    List<dynamic> whereArgs = [phoneNumber];

    if (messageType != null) {
      where += ' AND message_type = ?';
      whereArgs.add(messageType);
    }
    if (direction != null) {
      where += ' AND message_direction = ?';
      whereArgs.add(direction);
    }

    final maps = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final messages = List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
    return messages.reversed.toList();
  }

  Future<List<LocalMessage>> getMessagesByPeerUserId(
    String peerUserId, {
    int limit = 100,
    int offset = 0,
    String? messageType,
    String? direction,
  }) async {
    final db = await _db.database;
    String where = 'peer_user_id = ? AND is_deleted = 0 AND delete_for_me = 0';
    List<dynamic> whereArgs = [peerUserId];

    if (messageType != null) {
      where += ' AND message_type = ?';
      whereArgs.add(messageType);
    }
    if (direction != null) {
      where += ' AND message_direction = ?';
      whereArgs.add(direction);
    }

    final maps = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final messages = List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
    return messages.reversed.toList();
  }

  Future<List<LocalMessage>> getMessagesBeforeDate(
    String phoneNumber,
    String beforeDate, {
    int limit = 50,
  }) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND created_at < ? AND is_deleted = 0 AND delete_for_me = 0',
      whereArgs: [phoneNumber, beforeDate],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i])).reversed.toList();
  }

  Future<List<LocalMessage>> getMessagesAfterDate(
    String phoneNumber,
    String afterDate, {
    int limit = 50,
  }) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND created_at > ? AND is_deleted = 0 AND delete_for_me = 0',
      whereArgs: [phoneNumber, afterDate],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<List<LocalMessage>> searchMessages(String phoneNumber, String query) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND message_type = \'text\' AND content LIKE ? AND is_deleted = 0',
      whereArgs: [phoneNumber, '%$query%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<List<LocalMessage>> getStarredMessages(String phoneNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND is_starred = 1 AND is_deleted = 0',
      whereArgs: [phoneNumber],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<List<LocalMessage>> getMediaMessages(String phoneNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND message_type IN (\'image\', \'video\', \'voice\', \'document\') AND is_deleted = 0',
      whereArgs: [phoneNumber],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<int> updateMessage(LocalMessage message) async {
    if (message.id == null) throw Exception('Cannot update message with null ID');
    final db = await _db.database;
    return await db.update(
      'messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<int> updateMessageStatus(int messageId, String status) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> updateMessageField(int messageId, String field, dynamic value) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        field: value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> updateMessageFieldByServerId(String serverId, String field, dynamic value) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        field: value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'server_message_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<int> updateServerMessageId(int messageId, String serverId) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'server_message_id': serverId,
        'status': 'delivered',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> markMessageAsFailed(int messageId, String errorMessage) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'status': 'failed',
        'error_message': errorMessage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> toggleStarMessage(int messageId) async {
    final db = await _db.database;
    return await db.rawUpdate(
      'UPDATE messages SET is_starred = 1 - is_starred, updated_at = strftime(\'%Y-%m-%dT%H:%M:%fZ\', \'now\') WHERE id = ?',
      [messageId],
    );
  }

  Future<int> softDeleteMessage(int messageId) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'is_deleted': 1,
        'delete_for_me': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> updateMediaLocalPath(int messageId, String localPath) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'media_local_path': localPath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessageForEveryone(int messageId) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'is_deleted': 1,
        'delete_for_me': 0,
        'content': '🚫 This message was deleted',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessage(int messageId) async {
    final db = await _db.database;
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessagesByPhone(String phoneNumber) async {
    final db = await _db.database;
    return await db.delete(
      'messages',
      where: 'chat_phone_number = ?',
      whereArgs: [phoneNumber],
    );
  }

  Future<int> deleteMessagesByPeerUserId(String peerUserId) async {
    final db = await _db.database;
    return await db.delete(
      'messages',
      where: 'peer_user_id = ?',
      whereArgs: [peerUserId],
    );
  }

  Future<LocalMessage?> getLatestMessageByPhone(String phoneNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND is_deleted = 0 AND delete_for_me = 0',
      whereArgs: [phoneNumber],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocalMessage.fromMap(maps.first);
  }

  Future<int> getMessageCount(String phoneNumber) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE chat_phone_number = ? AND is_deleted = 0',
      [phoneNumber],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUnsentMessagesCount(String phoneNumber) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE chat_phone_number = ? AND message_direction = \'sent\' AND status IN (\'sending\', \'failed\')',
      [phoneNumber],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<LocalMessage>> getUnsentMessages(String phoneNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'chat_phone_number = ? AND message_direction = \'sent\' AND status IN (\'sending\', \'failed\')',
      whereArgs: [phoneNumber],
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<int> getMessageCountByServerId(String serverId) async {
    if (serverId.isEmpty) return 0;
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE server_message_id = ?',
      [serverId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<LocalMessage?> getMessageByClientUuid(String clientUuid) async {
    if (clientUuid.isEmpty) return null;
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
    if (maps.isEmpty) return null;
    return LocalMessage.fromMap(maps.first);
  }

  Future<int> updateMessageSequenceId(int messageId, int sequenceId) async {
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'sequence_id': sequenceId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> getHighestSequenceId() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT MAX(sequence_id) as max_seq FROM messages',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<LocalMessage>> getMessagesAfterSequence(int lastSequenceId, {int limit = 100}) async {
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'sequence_id > ? AND is_deleted = 0 AND delete_for_me = 0',
      whereArgs: [lastSequenceId],
      orderBy: 'sequence_id ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => LocalMessage.fromMap(maps[i]));
  }

  Future<LocalMessage?> getMessageByServerId(String serverId) async {
    if (serverId.isEmpty) return null;
    final db = await _db.database;
    final maps = await db.query(
      'messages',
      where: 'server_message_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocalMessage.fromMap(maps.first);
  }

  Future<int> updateMessageStatusByServerId(String serverId, String status) async {
    if (serverId.isEmpty) return 0;
    final db = await _db.database;
    return await db.update(
      'messages',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'server_message_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<void> deleteAllMessages() async {
    final db = await _db.database;
    await db.delete('messages');
  }
}
