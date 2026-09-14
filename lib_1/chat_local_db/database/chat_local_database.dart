import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatLocalDatabase {
  static final ChatLocalDatabase instance = ChatLocalDatabase._init();
  static Database? _database;

  ChatLocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('starlight_chat_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = -8000');
    await db.execute('PRAGMA temp_store = MEMORY');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE chats ADD COLUMN disappearing_timer INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE chats ADD COLUMN peer_user_id TEXT DEFAULT \'\'');
        await db.execute('CREATE INDEX idx_chats_peer_user ON chats(peer_user_id)');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN peer_user_id TEXT DEFAULT \'\'');
        await db.execute('ALTER TABLE messages ADD COLUMN sequence_id INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE messages ADD COLUMN client_uuid TEXT DEFAULT \'\'');
        await db.execute('ALTER TABLE messages ADD COLUMN media_blurhash TEXT DEFAULT \'\'');
        await db.execute('CREATE INDEX idx_messages_peer_user ON messages(peer_user_id)');
        await db.execute('CREATE INDEX idx_messages_sequence ON messages(sequence_id)');
        await db.execute('CREATE INDEX idx_messages_client_uuid ON messages(client_uuid)');
      } catch (e) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN is_edited INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE messages ADD COLUMN edited_at TEXT DEFAULT \'\'');
        await db.execute('ALTER TABLE messages ADD COLUMN original_content TEXT DEFAULT \'\'');
      } catch (e) {}
      try {
        await db.execute('''
          CREATE TABLE groups (
            group_id TEXT PRIMARY KEY,
            group_name TEXT NOT NULL DEFAULT '',
            group_description TEXT DEFAULT '',
            group_icon_url TEXT DEFAULT '',
            admin_user_id TEXT NOT NULL DEFAULT '',
            created_by TEXT NOT NULL DEFAULT '',
            member_count INTEGER NOT NULL DEFAULT 0,
            is_muted INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            disappearing_timer INTEGER NOT NULL DEFAULT 0,
            last_message TEXT DEFAULT '',
            last_message_time TEXT DEFAULT '',
            last_message_type TEXT DEFAULT 'text',
            last_message_sender TEXT DEFAULT '',
            unread_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
          )
        ''');
        await db.execute('CREATE INDEX idx_groups_updated ON groups(updated_at DESC)');
        await db.execute('CREATE INDEX idx_groups_unread ON groups(unread_count)');
      } catch (e) {}
      try {
        await db.execute('''
          CREATE TABLE group_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            phone_number TEXT DEFAULT '',
            display_name TEXT DEFAULT '',
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_group_members_group ON group_members(group_id)');
        await db.execute('CREATE INDEX idx_group_members_user ON group_members(user_id)');
        await db.execute('CREATE UNIQUE INDEX idx_group_members_unique ON group_members(group_id, user_id)');
      } catch (e) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE calls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_user_id TEXT NOT NULL,
            peer_name TEXT DEFAULT '',
            call_type TEXT NOT NULL DEFAULT 'voice',
            call_direction TEXT NOT NULL DEFAULT 'incoming',
            call_state TEXT NOT NULL DEFAULT 'missed',
            duration INTEGER NOT NULL DEFAULT 0,
            call_id TEXT DEFAULT '',
            is_self INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
          )
        ''');
        await db.execute('CREATE INDEX idx_calls_peer_user ON calls(peer_user_id)');
        await db.execute('CREATE INDEX idx_calls_call_id ON calls(call_id)');
        await db.execute('CREATE INDEX idx_calls_created ON calls(created_at DESC)');
      } catch (e) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE calls ADD COLUMN is_self INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE chats ADD COLUMN profile_picture_version INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE chats ADD COLUMN block_version INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE chats ADD COLUMN name_version INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE chats ADD COLUMN last_message_version INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN delete_for_me INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE chats ADD COLUMN is_locked INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE channels (
            channel_id TEXT PRIMARY KEY,
            name TEXT NOT NULL DEFAULT '',
            description TEXT DEFAULT '',
            created_by TEXT NOT NULL DEFAULT '',
            is_public INTEGER NOT NULL DEFAULT 1,
            member_user_ids TEXT DEFAULT '[]',
            member_count INTEGER NOT NULL DEFAULT 0,
            last_message TEXT DEFAULT '',
            last_message_time TEXT DEFAULT '',
            last_message_type TEXT DEFAULT 'text',
            last_message_sender TEXT DEFAULT '',
            unread_count INTEGER NOT NULL DEFAULT 0,
            is_muted INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            am_i_admin INTEGER NOT NULL DEFAULT 0,
            local_cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
          )
        ''');
        await db.execute('CREATE INDEX idx_channels_updated ON channels(updated_at DESC)');
        await db.execute('CREATE INDEX idx_channels_unread ON channels(unread_count)');
        await db.execute('CREATE INDEX idx_channels_created_by ON channels(created_by)');
      } catch (e) {}
      try {
        await db.execute('''
          CREATE TABLE channel_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel_id TEXT NOT NULL,
            sender_user_id TEXT NOT NULL,
            sender_name TEXT DEFAULT '',
            sequence_id INTEGER DEFAULT 0,
            client_uuid TEXT DEFAULT '',
            message_type TEXT NOT NULL DEFAULT 'text',
            content TEXT DEFAULT '',
            media_local_path TEXT DEFAULT '',
            media_remote_url TEXT DEFAULT '',
            media_file_name TEXT DEFAULT '',
            media_mime_type TEXT DEFAULT '',
            media_size_bytes INTEGER DEFAULT 0,
            media_duration_ms INTEGER DEFAULT 0,
            media_blurhash TEXT DEFAULT '',
            is_starred INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            delete_for_me INTEGER NOT NULL DEFAULT 0,
            is_edited INTEGER NOT NULL DEFAULT 0,
            edited_at TEXT DEFAULT '',
            reply_to_message_id INTEGER DEFAULT 0,
            reply_to_content TEXT DEFAULT '',
            forwarded_from TEXT DEFAULT '',
            status TEXT NOT NULL DEFAULT 'sent',
            server_message_id TEXT DEFAULT '',
            error_message TEXT DEFAULT '',
            created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
            FOREIGN KEY (channel_id) REFERENCES channels(channel_id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_channel_messages_channel ON channel_messages(channel_id)');
        await db.execute('CREATE INDEX idx_channel_messages_sequence ON channel_messages(sequence_id)');
        await db.execute('CREATE INDEX idx_channel_messages_client_uuid ON channel_messages(client_uuid)');
        await db.execute('CREATE INDEX idx_channel_messages_created_at ON channel_messages(created_at DESC)');
      } catch (e) {}
      try {
        await db.execute('''
          CREATE TABLE channel_members_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            display_name TEXT DEFAULT '',
            phone_number TEXT DEFAULT '',
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TEXT DEFAULT '',
            FOREIGN KEY (channel_id) REFERENCES channels(channel_id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_channel_members_channel ON channel_members_cache(channel_id)');
        await db.execute('CREATE INDEX idx_channel_members_user ON channel_members_cache(user_id)');
        await db.execute('CREATE UNIQUE INDEX idx_channel_members_unique ON channel_members_cache(channel_id, user_id)');
      } catch (e) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE calls ADD COLUMN peer_avatar TEXT DEFAULT ""');
      } catch (e) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        phone_number TEXT PRIMARY KEY,
        peer_user_id TEXT DEFAULT '',
        contact_name TEXT NOT NULL DEFAULT '',
        profile_image_url TEXT DEFAULT '',
        last_message TEXT DEFAULT '',
        last_message_time TEXT DEFAULT '',
        last_message_type TEXT DEFAULT 'text',
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_blocked INTEGER NOT NULL DEFAULT 0,
        disappearing_timer INTEGER NOT NULL DEFAULT 0,
        chat_created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        chat_updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        profile_picture_version INTEGER NOT NULL DEFAULT 0,
        block_version INTEGER NOT NULL DEFAULT 0,
        name_version INTEGER NOT NULL DEFAULT 0,
        last_message_version INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_chats_peer_user ON chats(peer_user_id)
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_phone_number TEXT NOT NULL,
        peer_user_id TEXT DEFAULT '',
        sequence_id INTEGER DEFAULT 0,
        client_uuid TEXT DEFAULT '',
        message_type TEXT NOT NULL DEFAULT 'text',
        message_direction TEXT NOT NULL DEFAULT 'sent',
        content TEXT DEFAULT '',
        media_local_path TEXT DEFAULT '',
        media_remote_url TEXT DEFAULT '',
        media_file_name TEXT DEFAULT '',
        media_mime_type TEXT DEFAULT '',
        media_size_bytes INTEGER DEFAULT 0,
        media_duration_ms INTEGER DEFAULT 0,
        media_width INTEGER DEFAULT 0,
        media_height INTEGER DEFAULT 0,
        media_thumbnail_path TEXT DEFAULT '',
        media_blurhash TEXT DEFAULT '',
        is_starred INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        delete_for_me INTEGER NOT NULL DEFAULT 0,
        is_edited INTEGER NOT NULL DEFAULT 0,
        edited_at TEXT DEFAULT '',
        original_content TEXT DEFAULT '',
        reply_to_message_id INTEGER DEFAULT 0,
        reply_to_content TEXT DEFAULT '',
        forwarded_from TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'sent',
        server_message_id TEXT DEFAULT '',
        error_message TEXT DEFAULT '',
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (chat_phone_number) REFERENCES chats(phone_number) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_chat_phone ON messages(chat_phone_number)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_peer_user ON messages(peer_user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_sequence ON messages(sequence_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_client_uuid ON messages(client_uuid)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_created_at ON messages(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_type ON messages(message_type)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_direction ON messages(message_direction)
    ''');

    await db.execute('''
      CREATE INDEX idx_chats_updated ON chats(chat_updated_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_chats_unread ON chats(unread_count)
    ''');

    await db.execute('''
      CREATE TABLE media_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id INTEGER NOT NULL,
        file_path TEXT NOT NULL UNIQUE,
        file_type TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        is_downloaded INTEGER NOT NULL DEFAULT 0,
        download_progress REAL DEFAULT 0.0,
        last_accessed TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO chat_settings (key, value) VALUES
        ('auto_download_wifi', 'true'),
        ('auto_download_mobile', 'false'),
        ('media_quality', 'high'),
        ('default_chat_folder', 'all')
    ''');

    await db.execute('''
      CREATE TABLE groups (
        group_id TEXT PRIMARY KEY,
        group_name TEXT NOT NULL DEFAULT '',
        group_description TEXT DEFAULT '',
        group_icon_url TEXT DEFAULT '',
        admin_user_id TEXT NOT NULL DEFAULT '',
        created_by TEXT NOT NULL DEFAULT '',
        member_count INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        disappearing_timer INTEGER NOT NULL DEFAULT 0,
        last_message TEXT DEFAULT '',
        last_message_time TEXT DEFAULT '',
        last_message_type TEXT DEFAULT 'text',
        last_message_sender TEXT DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await db.execute('CREATE INDEX idx_groups_updated ON groups(updated_at DESC)');
    await db.execute('CREATE INDEX idx_groups_unread ON groups(unread_count)');

    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        phone_number TEXT DEFAULT '',
        display_name TEXT DEFAULT '',
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_group_members_group ON group_members(group_id)');
    await db.execute('CREATE INDEX idx_group_members_user ON group_members(user_id)');
    await db.execute('CREATE UNIQUE INDEX idx_group_members_unique ON group_members(group_id, user_id)');

    await db.execute('''
      CREATE TABLE group_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id TEXT NOT NULL,
        sender_user_id TEXT NOT NULL,
        sender_name TEXT DEFAULT '',
        sequence_id INTEGER DEFAULT 0,
        client_uuid TEXT DEFAULT '',
        message_type TEXT NOT NULL DEFAULT 'text',
        content TEXT DEFAULT '',
        media_local_path TEXT DEFAULT '',
        media_remote_url TEXT DEFAULT '',
        media_file_name TEXT DEFAULT '',
        media_mime_type TEXT DEFAULT '',
        media_size_bytes INTEGER DEFAULT 0,
        media_duration_ms INTEGER DEFAULT 0,
        media_blurhash TEXT DEFAULT '',
        is_starred INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        delete_for_me INTEGER NOT NULL DEFAULT 0,
        is_edited INTEGER NOT NULL DEFAULT 0,
        edited_at TEXT DEFAULT '',
        reply_to_message_id INTEGER DEFAULT 0,
        reply_to_content TEXT DEFAULT '',
        forwarded_from TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'sent',
        server_message_id TEXT DEFAULT '',
        error_message TEXT DEFAULT '',
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (group_id) REFERENCES groups(group_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_group_messages_group ON group_messages(group_id)');
    await db.execute('CREATE INDEX idx_group_messages_sequence ON group_messages(sequence_id)');
    await db.execute('CREATE INDEX idx_group_messages_client_uuid ON group_messages(client_uuid)');
    await db.execute('CREATE INDEX idx_group_messages_created_at ON group_messages(created_at DESC)');

    await db.execute('''
      CREATE TABLE presence_cache (
        user_id TEXT PRIMARY KEY,
        phone_number TEXT DEFAULT '',
        is_online INTEGER NOT NULL DEFAULT 0,
        last_seen TEXT DEFAULT '',
        typing_in TEXT DEFAULT '',
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE calls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        peer_user_id TEXT NOT NULL,
        peer_name TEXT DEFAULT '',
        peer_avatar TEXT DEFAULT '',
        call_type TEXT NOT NULL DEFAULT 'voice',
        call_direction TEXT NOT NULL DEFAULT 'incoming',
        call_state TEXT NOT NULL DEFAULT 'missed',
        duration INTEGER NOT NULL DEFAULT 0,
        call_id TEXT DEFAULT '',
        is_self INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await db.execute('CREATE INDEX idx_calls_peer_user ON calls(peer_user_id)');
    await db.execute('CREATE INDEX idx_calls_call_id ON calls(call_id)');
    await db.execute('CREATE INDEX idx_calls_created ON calls(created_at DESC)');

    await db.execute('''
      CREATE TABLE channels (
        channel_id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        description TEXT DEFAULT '',
        created_by TEXT NOT NULL DEFAULT '',
        is_public INTEGER NOT NULL DEFAULT 1,
        member_user_ids TEXT DEFAULT '[]',
        member_count INTEGER NOT NULL DEFAULT 0,
        last_message TEXT DEFAULT '',
        last_message_time TEXT DEFAULT '',
        last_message_type TEXT DEFAULT 'text',
        last_message_sender TEXT DEFAULT '',
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        am_i_admin INTEGER NOT NULL DEFAULT 0,
        local_cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');
    await db.execute('CREATE INDEX idx_channels_updated ON channels(updated_at DESC)');
    await db.execute('CREATE INDEX idx_channels_unread ON channels(unread_count)');
    await db.execute('CREATE INDEX idx_channels_created_by ON channels(created_by)');

    await db.execute('''
      CREATE TABLE channel_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL,
        sender_user_id TEXT NOT NULL,
        sender_name TEXT DEFAULT '',
        sequence_id INTEGER DEFAULT 0,
        client_uuid TEXT DEFAULT '',
        message_type TEXT NOT NULL DEFAULT 'text',
        content TEXT DEFAULT '',
        media_local_path TEXT DEFAULT '',
        media_remote_url TEXT DEFAULT '',
        media_file_name TEXT DEFAULT '',
        media_mime_type TEXT DEFAULT '',
        media_size_bytes INTEGER DEFAULT 0,
        media_duration_ms INTEGER DEFAULT 0,
        media_blurhash TEXT DEFAULT '',
        is_starred INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        delete_for_me INTEGER NOT NULL DEFAULT 0,
        is_edited INTEGER NOT NULL DEFAULT 0,
        edited_at TEXT DEFAULT '',
        reply_to_message_id INTEGER DEFAULT 0,
        reply_to_content TEXT DEFAULT '',
        forwarded_from TEXT DEFAULT '',
        status TEXT NOT NULL DEFAULT 'sent',
        server_message_id TEXT DEFAULT '',
        error_message TEXT DEFAULT '',
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        FOREIGN KEY (channel_id) REFERENCES channels(channel_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_channel_messages_channel ON channel_messages(channel_id)');
    await db.execute('CREATE INDEX idx_channel_messages_sequence ON channel_messages(sequence_id)');
    await db.execute('CREATE INDEX idx_channel_messages_client_uuid ON channel_messages(client_uuid)');
    await db.execute('CREATE INDEX idx_channel_messages_created_at ON channel_messages(created_at DESC)');

    await db.execute('''
      CREATE TABLE channel_members_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        display_name TEXT DEFAULT '',
        phone_number TEXT DEFAULT '',
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT DEFAULT '',
        FOREIGN KEY (channel_id) REFERENCES channels(channel_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_channel_members_channel ON channel_members_cache(channel_id)');
    await db.execute('CREATE INDEX idx_channel_members_user ON channel_members_cache(user_id)');
    await db.execute('CREATE UNIQUE INDEX idx_channel_members_unique ON channel_members_cache(channel_id, user_id)');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'starlight_chat_local.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
