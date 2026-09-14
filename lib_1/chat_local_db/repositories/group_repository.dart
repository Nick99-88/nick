import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/models.dart';

class GroupRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<void> insertGroup(LocalGroup group) async {
    final db = await _db.database;
    await db.insert(
      'groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LocalGroup?> getGroup(String groupId) async {
    final db = await _db.database;
    final maps = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    if (maps.isEmpty) return null;
    return LocalGroup.fromMap(maps.first);
  }

  Future<List<LocalGroup>> getAllGroups({
    bool includeArchived = false,
    bool includeBlocked = false,
  }) async {
    final db = await _db.database;
    String where = '';
    if (!includeArchived) {
      where = 'is_archived = 0';
    }
    final maps = await db.query(
      'groups',
      where: where.isNotEmpty ? where : null,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => LocalGroup.fromMap(maps[i]));
  }

  Future<List<LocalGroup>> searchGroups(String query) async {
    final db = await _db.database;
    final maps = await db.query(
      'groups',
      where: 'group_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => LocalGroup.fromMap(maps[i]));
  }

  Future<void> updateGroup(LocalGroup group) async {
    final db = await _db.database;
    await db.update(
      'groups',
      group.toMap(),
      where: 'group_id = ?',
      whereArgs: [group.groupId],
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await _db.database;
    await db.delete('groups', where: 'group_id = ?', whereArgs: [groupId]);
  }

  Future<void> updateGroupLastMessage(
    String groupId,
    String message,
    String type,
    String sender,
  ) async {
    final db = await _db.database;
    await db.update(
      'groups',
      {
        'last_message': message,
        'last_message_type': type,
        'last_message_sender': sender,
        'last_message_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> incrementUnreadCount(String groupId) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE groups SET unread_count = unread_count + 1 WHERE group_id = ?',
      [groupId],
    );
  }

  Future<void> resetUnreadCount(String groupId) async {
    final db = await _db.database;
    await db.update(
      'groups',
      {'unread_count': 0},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // Group Members
  Future<void> insertMember(GroupMember member) async {
    final db = await _db.database;
    await db.insert(
      'group_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMembers(List<GroupMember> members) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final member in members) {
      batch.insert(
        'group_members',
        member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final db = await _db.database;
    final maps = await db.query(
      'group_members',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: "CASE role WHEN 'creator' THEN 1 WHEN 'admin' THEN 2 ELSE 3 END, display_name ASC",
    );
    return List.generate(maps.length, (i) => GroupMember.fromMap(maps[i]));
  }

  Future<GroupMember?> getMember(String groupId, String userId) async {
    final db = await _db.database;
    final maps = await db.query(
      'group_members',
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    if (maps.isEmpty) return null;
    return GroupMember.fromMap(maps.first);
  }

  Future<void> removeMember(String groupId, String userId) async {
    final db = await _db.database;
    await db.delete(
      'group_members',
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    await _updateMemberCount(groupId);
  }

  Future<void> updateMemberRole(String groupId, String userId, String role) async {
    final db = await _db.database;
    await db.update(
      'group_members',
      {'role': role},
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
  }

  Future<int> getMemberCount(String groupId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM group_members WHERE group_id = ?',
      [groupId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> _updateMemberCount(String groupId) async {
    final count = await getMemberCount(groupId);
    final db = await _db.database;
    await db.update(
      'groups',
      {'member_count': count},
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // Group Messages
  Future<int> insertGroupMessage(LocalMessage message, String groupId) async {
    final db = await _db.database;
    final map = message.toMap();
    map['group_id'] = groupId;
    map.remove('chat_phone_number');
    map.remove('peer_user_id');
    return await db.insert('group_messages', map);
  }

  Future<List<LocalMessage>> getGroupMessages(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db.database;
    final maps = await db.query(
      'group_messages',
      where: 'group_id = ? AND (is_deleted = 0 OR delete_for_me = 0)',
      whereArgs: [groupId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    final messages = List.generate(maps.length, (i) {
      final map = maps[i];
      map['chat_phone_number'] = '';
      map['peer_user_id'] = '';
      return LocalMessage.fromMap(map);
    });
    return messages.reversed.toList();
  }

  Future<LocalMessage?> getGroupMessageByClientUuid(String groupId, String clientUuid) async {
    final db = await _db.database;
    final maps = await db.query(
      'group_messages',
      where: 'group_id = ? AND client_uuid = ?',
      whereArgs: [groupId, clientUuid],
    );
    if (maps.isEmpty) return null;
    final map = maps.first;
    map['chat_phone_number'] = '';
    map['peer_user_id'] = '';
    return LocalMessage.fromMap(map);
  }

  Future<void> updateGroupMessageStatus(String groupId, String clientUuid, String status) async {
    final db = await _db.database;
    await db.update(
      'group_messages',
      {'status': status},
      where: 'group_id = ? AND client_uuid = ?',
      whereArgs: [groupId, clientUuid],
    );
  }

  Future<void> deleteGroupMessageForMe(String groupId, int messageId) async {
    final db = await _db.database;
    await db.update(
      'group_messages',
      {'delete_for_me': 1},
      where: 'group_id = ? AND id = ?',
      whereArgs: [groupId, messageId],
    );
  }

  Future<void> deleteGroupMessageForEveryone(String groupId, String clientUuid) async {
    final db = await _db.database;
    await db.update(
      'group_messages',
      {'is_deleted': 1},
      where: 'group_id = ? AND client_uuid = ?',
      whereArgs: [groupId, clientUuid],
    );
  }

  Future<void> editGroupMessage(String groupId, String clientUuid, String newContent) async {
    final db = await _db.database;
    await db.update(
      'group_messages',
      {
        'content': newContent,
        'is_edited': 1,
        'edited_at': DateTime.now().toIso8601String(),
      },
      where: 'group_id = ? AND client_uuid = ?',
      whereArgs: [groupId, clientUuid],
    );
  }
}
