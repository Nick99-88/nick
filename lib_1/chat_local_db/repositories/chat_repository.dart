import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../models/models.dart';

class ChatRepository {
  final ChatLocalDatabase _db = ChatLocalDatabase.instance;

  Future<int> insertChat(LocalChat chat) async {
    final db = await _db.database;
    return await db.insert(
      'chats',
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<LocalChat?> getChatByPhone(String phoneNumber) async {
    final db = await _db.database;
    final maps = await db.query(
      'chats',
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
    );
    if (maps.isEmpty) return null;
    return LocalChat.fromMap(maps.first);
  }

  Future<LocalChat?> getChatByPeerUserId(String peerUserId) async {
    if (peerUserId.isEmpty) return null;
    final db = await _db.database;
    final maps = await db.query(
      'chats',
      where: 'peer_user_id = ?',
      whereArgs: [peerUserId],
    );
    if (maps.isEmpty) return null;
    return LocalChat.fromMap(maps.first);
  }

  Future<LocalChat> getOrCreateChat(String phoneNumber, {String? contactName, String? peerUserId}) async {
    var chat = await getChatByPhone(phoneNumber);
    if (chat == null && peerUserId != null && peerUserId.isNotEmpty) {
      chat = await getChatByPeerUserId(peerUserId);
    }
    if (chat == null) {
      chat = LocalChat(
        phoneNumber: phoneNumber,
        peerUserId: peerUserId ?? '',
        contactName: contactName ?? phoneNumber,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await insertChat(chat);
    } else if (peerUserId != null && peerUserId.isNotEmpty && chat.peerUserId.isEmpty) {
      await updateChat(chat.copyWith(peerUserId: peerUserId));
    }
    return chat;
  }

  Future<List<LocalChat>> getAllChats({
    bool includeArchived = false,
    bool includeBlocked = false,
    int limit = 0,
    int offset = 0,
  }) async {
    final db = await _db.database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (!includeArchived) {
      where += 'is_archived = 0';
    }
    if (!includeBlocked) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'is_blocked = 0';
    }

    String orderBy = 'is_pinned DESC, chat_updated_at DESC';
    String limitClause = limit > 0 ? 'LIMIT $limit OFFSET $offset' : '';

    final maps = await db.query(
      'chats',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) => LocalChat.fromMap(maps[i]));
  }

  Future<List<LocalChat>> searchChats(String query) async {
    final db = await _db.database;
    final maps = await db.query(
      'chats',
      where: 'contact_name LIKE ? OR phone_number LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'is_pinned DESC, chat_updated_at DESC',
    );
    return List.generate(maps.length, (i) => LocalChat.fromMap(maps[i]));
  }

  Future<int> updateChat(LocalChat chat) async {
    final db = await _db.database;
    return await db.update(
      'chats',
      chat.toMap(),
      where: 'phone_number = ?',
      whereArgs: [chat.phoneNumber],
    );
  }

  Future<int> updateChatField(String phoneNumber, String field, dynamic value) async {
    final db = await _db.database;
    return await db.update(
      'chats',
      {field: value},
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
    );
  }

  Future<int> incrementUnreadCount(String phoneNumber) async {
    final db = await _db.database;
    return await db.rawUpdate(
      'UPDATE chats SET unread_count = unread_count + 1, chat_updated_at = strftime(\'%Y-%m-%dT%H:%M:%fZ\', \'now\') WHERE phone_number = ?',
      [phoneNumber],
    );
  }

  Future<int> resetUnreadCount(String phoneNumber) async {
    final db = await _db.database;
    return await db.update(
      'chats',
      {
        'unread_count': 0,
        'chat_updated_at': DateTime.now().toIso8601String(),
      },
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
    );
  }

  Future<int> updateLastMessage(
    String phoneNumber,
    String message,
    String messageType, {
    String? messageTime,
  }) async {
    final db = await _db.database;
    final timestamp = messageTime ?? DateTime.now().toIso8601String();
    return await db.update(
      'chats',
      {
        'last_message': message,
        'last_message_type': messageType,
        'last_message_time': timestamp,
        'chat_updated_at': timestamp,
      },
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
    );
  }

  Future<int> toggleMute(String phoneNumber, bool isMuted) async {
    return updateChatField(phoneNumber, 'is_muted', isMuted ? 1 : 0);
  }

  Future<int> togglePin(String phoneNumber, bool isPinned) async {
    return updateChatField(phoneNumber, 'is_pinned', isPinned ? 1 : 0);
  }

  Future<int> toggleArchive(String phoneNumber, bool isArchived) async {
    return updateChatField(phoneNumber, 'is_archived', isArchived ? 1 : 0);
  }

  Future<int> toggleBlock(String phoneNumber, bool isBlocked) async {
    return updateChatField(phoneNumber, 'is_blocked', isBlocked ? 1 : 0);
  }

  Future<int> toggleLock(String phoneNumber, bool isLocked) async {
    return updateChatField(phoneNumber, 'is_locked', isLocked ? 1 : 0);
  }

  Future<int> deleteChat(String phoneNumber) async {
    final db = await _db.database;
    return await db.delete(
      'chats',
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
    );
  }

  Future<void> updatePhoneNumber(String oldPhone, String newPhone) async {
    final existing = await getChatByPhone(oldPhone);
    if (existing == null) return;
    final duplicate = await getChatByPhone(newPhone);
    if (duplicate != null) {
      final merged = duplicate.copyWith(
        profileImageUrl: existing.profileImageUrl.isNotEmpty ? existing.profileImageUrl : duplicate.profileImageUrl,
        profilePictureVersion: existing.profilePictureVersion > duplicate.profilePictureVersion
            ? existing.profilePictureVersion : duplicate.profilePictureVersion,
        contactName: existing.contactName.isNotEmpty ? existing.contactName : duplicate.contactName,
      );
      await updateChat(merged);
      await deleteChat(oldPhone);
    } else {
      await deleteChat(oldPhone);
      await insertChat(existing.copyWith(phoneNumber: newPhone));
    }
  }

  Future<int> getUnreadChatsCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM chats WHERE unread_count > 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalChatsCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM chats');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteAllChats() async {
    final db = await _db.database;
    await db.delete('chats');
  }

  /// Save friends list to local DB (stored in chats table keyed by peer_user_id)
  Future<void> saveFriends(List<Map<String, dynamic>> friends) async {
    final db = await _db.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (final friend in friends) {
      final peerUserId = friend['id']?.toString() ?? '';
      if (peerUserId.isEmpty) continue;
      
      batch.insert(
        'chats',
        {
          'phone_number': peerUserId,
          'peer_user_id': peerUserId,
          'contact_name': friend['name']?.toString() ?? peerUserId,
          'profile_image_url': friend['avatar']?.toString() ?? '',
          'last_message': '',
          'last_message_time': now,
          'last_message_type': 'text',
          'unread_count': 0,
          'is_muted': 0,
          'is_archived': 0,
          'is_pinned': 0,
          'is_blocked': 0,
          'is_locked': 0,
          'disappearing_timer': 0,
          'chat_created_at': now,
          'chat_updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get all friends from local DB (friends stored with phone_number = peer_user_id)
  Future<List<LocalChat>> getFriends() async {
    final db = await _db.database;
    final maps = await db.query(
      'chats',
      where: 'peer_user_id != \'\' AND phone_number = peer_user_id',
      orderBy: 'is_pinned DESC, contact_name ASC',
    );
    return List.generate(maps.length, (i) => LocalChat.fromMap(maps[i]));
  }
}
