import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DashboardLocalDb {
  static final DashboardLocalDb instance = DashboardLocalDb._init();
  static Database? _database;

  DashboardLocalDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('starlight_dashboard.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
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
      await db.execute("ALTER TABLE pending_ops ADD COLUMN status TEXT DEFAULT 'pending'");
      await db.execute("ALTER TABLE pending_ops ADD COLUMN previous_state TEXT DEFAULT ''");
      await db.execute("ALTER TABLE pending_ops ADD COLUMN idempotency_key TEXT DEFAULT ''");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS failed_ops (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          op_id INTEGER,
          entity_type TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          previous_state TEXT DEFAULT '',
          error_message TEXT DEFAULT '',
          error_status_code INTEGER DEFAULT 0,
          failed_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_students (
        server_id TEXT,
        local_id TEXT,
        section TEXT NOT NULL,
        name TEXT NOT NULL,
        father_name TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        fee REAL DEFAULT 0,
        extra_fields TEXT DEFAULT '{}',
        sync_status TEXT DEFAULT 'done',
        cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (server_id, section)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cs_section ON cached_students(section)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cs_name ON cached_students(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cs_sync ON cached_students(sync_status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_teachers (
        server_id TEXT PRIMARY KEY,
        local_id TEXT,
        name TEXT NOT NULL,
        subject_expertise TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        salary REAL DEFAULT 0,
        joining_date TEXT DEFAULT '',
        extra_details TEXT DEFAULT '{}',
        sync_status TEXT DEFAULT 'done',
        cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ct_subject ON cached_teachers(subject_expertise)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ct_sync ON cached_teachers(sync_status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_staff (
        server_id TEXT PRIMARY KEY,
        local_id TEXT,
        name TEXT NOT NULL,
        position TEXT NOT NULL,
        cnic TEXT DEFAULT '',
        contact TEXT DEFAULT '',
        extra_details TEXT DEFAULT '{}',
        sync_status TEXT DEFAULT 'done',
        cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cst_position ON cached_staff(position)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cst_sync ON cached_staff(sync_status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_string_list (
        list_type TEXT NOT NULL,
        value TEXT NOT NULL,
        sync_status TEXT DEFAULT 'done',
        cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (list_type, value)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_csl_type ON cached_string_list(list_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_csl_sync ON cached_string_list(sync_status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_section_teachers (
        section_name TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        subject_name TEXT DEFAULT '',
        sync_status TEXT DEFAULT 'done',
        cached_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        PRIMARY KEY (section_name, teacher_id, subject_name)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cst_section ON cached_section_teachers(section_name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cst_teacher ON cached_section_teachers(teacher_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cst_sync ON cached_section_teachers(sync_status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_ops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        original_value TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        previous_state TEXT DEFAULT '',
        idempotency_key TEXT DEFAULT '',
        created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        retry_count INTEGER DEFAULT 0,
        last_error TEXT DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_entity ON pending_ops(entity_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_retry ON pending_ops(retry_count)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_status ON pending_ops(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS failed_ops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        op_id INTEGER,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        previous_state TEXT DEFAULT '',
        error_message TEXT DEFAULT '',
        error_status_code INTEGER DEFAULT 0,
        failed_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dashboard_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
      )
    ''');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Wipes all cached entity tables so they can be re-saved fresh from the server.
  /// Pending operations are preserved (in [pending_ops]) so offline edits replay later.
  Future<void> clearAllEntities() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_students');
      await txn.delete('cached_teachers');
      await txn.delete('cached_staff');
      await txn.delete('cached_string_list');
      await txn.delete('cached_section_teachers');
    });
  }

  // ═══════════════════════════════════════
  // STUDENTS
  // ═══════════════════════════════════════

  Future<void> replaceStudents(List<dynamic> students) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_students', where: "sync_status = 'done'");
      for (final s in students) {
        await txn.insert('cached_students', _studentRow(s), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> upsertStudentSection(List<dynamic> students, String section) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_students', where: "section = ? AND sync_status = 'done'", whereArgs: [section]);
      for (final s in students) {
        await txn.insert('cached_students', _studentRow(s), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<String> insertPendingStudent(Map<String, dynamic> data) async {
    final db = await database;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final row = _studentRow(data);
    row['server_id'] = '';
    row['local_id'] = localId;
    row['sync_status'] = 'pending';
    await db.insert('cached_students', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return localId;
  }

  Future<void> upsertStudentFromServer(Map<String, dynamic> student) async {
    final db = await database;
    final row = _studentRow(student);
    row['sync_status'] = 'done';
    await db.insert('cached_students', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markStudentSynced(String serverId, String section, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.update('cached_students', {'server_id': serverId, 'sync_status': 'done'},
          where: 'local_id = ?', whereArgs: [localId]);
    } else {
      await db.update('cached_students', {'sync_status': 'done'},
          where: 'server_id = ? AND section = ?', whereArgs: [serverId, section]);
    }
  }

  Future<void> markStudentDeleted(String serverId, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.delete('cached_students', where: 'local_id = ?', whereArgs: [localId]);
    } else {
      await db.delete('cached_students', where: 'server_id = ?', whereArgs: [serverId]);
    }
  }

  Future<void> deleteStudentById(String id) async {
    final db = await database;
    await db.delete('cached_students', where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  Future<void> updateStudentRow(String id, Map<String, dynamic> data, {String syncStatus = 'pending'}) async {
    final db = await database;
    final extra = jsonEncode(_extractExtra(data, ['id', 'local_id', 'name', 'father_name', 'phone', 'fee', 'section_name', 'section', 'roll_number']));
    await db.update(
      'cached_students',
      {
        'name': data['name'] ?? '',
        'father_name': data['father_name'] ?? '',
        'phone': data['phone'] ?? '',
        'fee': (data['fee'] ?? 0).toDouble(),
        'section': data['section_name'] ?? data['section'] ?? '',
        'extra_fields': extra,
        'sync_status': syncStatus,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> markStudentRowSynced(String id) async {
    final db = await database;
    await db.update('cached_students', {'sync_status': 'done'}, where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  Future<List<Map<String, dynamic>>> getStudents({String? sectionFilter}) async {
    final db = await database;
    if (sectionFilter != null) {
      return (await db.query('cached_students', where: 'section = ?', whereArgs: [sectionFilter], orderBy: 'name ASC'))
          .map(_decodeRow).toList();
    }
    return (await db.query('cached_students', orderBy: 'section ASC, name ASC')).map(_decodeRow).toList();
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final db = await database;
    final q = '%$query%';
    return (await db.query('cached_students', where: 'name LIKE ? OR father_name LIKE ?', whereArgs: [q, q], orderBy: 'name ASC'))
        .map(_decodeRow).toList();
  }

  Map<String, dynamic> _studentRow(dynamic s) {
    return {
      'server_id': '${s['id'] ?? ''}',
      'local_id': s['local_id'] ?? '',
      'section': s['section_name'] ?? s['section'] ?? '',
      'name': s['name'] ?? '',
      'father_name': s['father_name'] ?? '',
      'phone': s['phone'] ?? '',
      'fee': (s['fee'] ?? 0).toDouble(),
      'extra_fields': jsonEncode(_extractExtra(s, ['id', 'local_id', 'name', 'father_name', 'phone', 'fee', 'section_name', 'section'])),
      'sync_status': s['sync_status'] ?? 'done',
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ═══════════════════════════════════════
  // TEACHERS
  // ═══════════════════════════════════════

  Future<void> replaceTeachers(List<dynamic> teachers) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_teachers', where: "sync_status = 'done'");
      for (final t in teachers) {
        await txn.insert('cached_teachers', _teacherRow(t), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> insertPendingTeacher(Map<String, dynamic> data) async {
    final db = await database;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final row = _teacherRow(data);
    row['server_id'] = '';
    row['local_id'] = localId;
    row['sync_status'] = 'pending';
    await db.insert('cached_teachers', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markTeacherSynced(String serverId, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.update('cached_teachers', {'server_id': serverId, 'sync_status': 'done'},
          where: 'local_id = ?', whereArgs: [localId]);
    }
  }

  Future<void> markTeacherDeleted(String serverId, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.delete('cached_teachers', where: 'local_id = ?', whereArgs: [localId]);
    } else {
      await db.delete('cached_teachers', where: 'server_id = ?', whereArgs: [serverId]);
    }
  }

  Future<void> deleteTeacherById(String id) async {
    final db = await database;
    await db.delete('cached_teachers', where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  Future<void> updateTeacherRow(String id, Map<String, dynamic> data, {String syncStatus = 'pending'}) async {
    final db = await database;
    final extra = jsonEncode(_extractExtra(data, ['id', 'local_id', 'name', 'subject_expertise', 'phone', 'salary', 'joining_date', 'designation']));
    await db.update(
      'cached_teachers',
      {
        'name': data['name'] ?? '',
        'subject_expertise': data['designation'] ?? data['subject_expertise'] ?? '',
        'phone': data['phone'] ?? '',
        'salary': (data['salary'] ?? 0).toDouble(),
        'joining_date': data['joining_date'] ?? '',
        'extra_details': extra,
        'sync_status': syncStatus,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> markTeacherRowSynced(String id) async {
    final db = await database;
    await db.update('cached_teachers', {'sync_status': 'done'}, where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  Future<List<Map<String, dynamic>>> getTeachers({String? subjectFilter}) async {
    final db = await database;
    if (subjectFilter != null) {
      return (await db.query('cached_teachers', where: 'subject_expertise LIKE ?', whereArgs: ['%$subjectFilter%'], orderBy: 'name ASC'))
          .map(_decodeRow).toList();
    }
    return (await db.query('cached_teachers', orderBy: 'name ASC')).map(_decodeRow).toList();
  }

  Map<String, dynamic> _teacherRow(dynamic t) {
    return {
      'server_id': '${t['id'] ?? ''}',
      'local_id': t['local_id'] ?? '',
      'name': t['name'] ?? '',
        'subject_expertise': t['subject_name'] ?? t['subject_expertise'] ?? t['designation'] ?? '',
      'phone': t['phone'] ?? '',
      'salary': (t['salary'] ?? 0).toDouble(),
      'joining_date': t['joining_date'] ?? '',
      'extra_details': jsonEncode(_extractExtra(t, ['id', 'local_id', 'name', 'subject_expertise', 'phone', 'salary', 'joining_date'])),
      'sync_status': t['sync_status'] ?? 'done',
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ═══════════════════════════════════════
  // STAFF
  // ═══════════════════════════════════════

  Future<void> replaceStaff(List<dynamic> staffList) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_staff', where: "sync_status = 'done'");
      for (final s in staffList) {
        await txn.insert('cached_staff', _staffRow(s), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> insertPendingStaff(Map<String, dynamic> data) async {
    final db = await database;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final row = _staffRow(data);
    row['server_id'] = '';
    row['local_id'] = localId;
    row['sync_status'] = 'pending';
    await db.insert('cached_staff', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markStaffSynced(String serverId, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.update('cached_staff', {'server_id': serverId, 'sync_status': 'done'},
          where: 'local_id = ?', whereArgs: [localId]);
    }
  }

  Future<void> markStaffDeleted(String serverId, String localId) async {
    final db = await database;
    if (localId.isNotEmpty) {
      await db.delete('cached_staff', where: 'local_id = ?', whereArgs: [localId]);
    } else {
      await db.delete('cached_staff', where: 'server_id = ?', whereArgs: [serverId]);
    }
  }

  Future<void> deleteStaffById(String id) async {
    final db = await database;
    await db.delete('cached_staff', where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  Future<void> updateStaffRow(String id, Map<String, dynamic> data, {String syncStatus = 'pending'}) async {
    final db = await database;
    final extra = jsonEncode(_extractExtra(data, ['id', 'local_id', 'name', 'position', 'cnic', 'contact', 'role_name']));
    await db.update(
      'cached_staff',
      {
        'name': data['name'] ?? '',
        'position': data['position'] ?? '',
        'cnic': data['cnic'] ?? '',
        'contact': data['contact'] ?? '',
        'extra_details': extra,
        'sync_status': syncStatus,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> markStaffRowSynced(String id) async {
    final db = await database;
    await db.update('cached_staff', {'sync_status': 'done'}, where: 'server_id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  // ═══════════════════════════════════════
  // SECTION ↔ TEACHER ASSIGNMENTS
  // ═══════════════════════════════════════

  Future<void> replaceSectionTeachers(String section, List<dynamic> teachers) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_section_teachers', where: 'section_name = ? AND sync_status = ?', whereArgs: [section, 'done']);
      for (final t in teachers) {
        await txn.insert('cached_section_teachers', _sectionTeacherRow(t, section), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Map<String, dynamic> _sectionTeacherRow(dynamic t, String section) {
    return {
      'section_name': section,
      'teacher_id': '${t['id'] ?? t['teacher_id'] ?? ''}',
      'subject_name': t['assigned_subject'] ?? t['subject_name'] ?? '',
      'sync_status': t['sync_status'] ?? 'done',
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> getSectionTeachers(String section) async {
    final db = await database;
    return (await db.query('cached_section_teachers', where: 'section_name = ?', whereArgs: [section])).map(_decodeRow).toList();
  }

  Future<void> insertSectionTeacher(String section, String teacherId, String subject, {String syncStatus = 'pending'}) async {
    final db = await database;
    await db.insert(
      'cached_section_teachers',
      {'section_name': section, 'teacher_id': teacherId, 'subject_name': subject, 'sync_status': syncStatus, 'cached_at': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSectionTeacher(String section, String teacherId, String subject) async {
    final db = await database;
    await db.delete(
      'cached_section_teachers',
      where: 'section_name = ? AND teacher_id = ? AND subject_name = ?',
      whereArgs: [section, teacherId, subject],
    );
  }

  Future<void> replaceTeacherSections(String teacherId, List<dynamic> sections) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_section_teachers', where: 'teacher_id = ? AND sync_status = ?', whereArgs: [teacherId, 'done']);
      for (final s in sections) {
        await txn.insert(
          'cached_section_teachers',
          {'section_name': '${s['section_name'] ?? ''}', 'teacher_id': teacherId, 'subject_name': '', 'sync_status': 'done', 'cached_at': DateTime.now().toUtc().toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTeacherSections(String teacherId) async {
    final db = await database;
    return (await db.query('cached_section_teachers', where: 'teacher_id = ?', whereArgs: [teacherId])).map(_decodeRow).toList();
  }

  Future<List<Map<String, dynamic>>> getStaff({String? roleFilter}) async {
    final db = await database;
    if (roleFilter != null) {
      return (await db.query('cached_staff', where: 'position LIKE ?', whereArgs: ['%$roleFilter%'], orderBy: 'name ASC'))
          .map(_decodeRow).toList();
    }
    return (await db.query('cached_staff', orderBy: 'name ASC')).map(_decodeRow).toList();
  }

  Map<String, dynamic> _staffRow(dynamic s) {
    return {
      'server_id': '${s['id'] ?? ''}',
      'local_id': s['local_id'] ?? '',
      'name': s['name'] ?? '',
      'position': s['position'] ?? '',
      'cnic': s['cnic'] ?? '',
      'contact': s['contact'] ?? '',
      'extra_details': jsonEncode(_extractExtra(s, ['id', 'local_id', 'name', 'position', 'cnic', 'contact'])),
      'sync_status': s['sync_status'] ?? 'done',
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // ═══════════════════════════════════════
  // STRING LISTS (sections, subjects, roles)
  // ═══════════════════════════════════════

  Future<void> replaceStringList(String listType, List<String> values) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_string_list', where: "list_type = ? AND sync_status = 'done'", whereArgs: [listType]);
      for (final v in values) {
        await txn.insert('cached_string_list', {
          'list_type': listType, 'value': v, 'sync_status': 'done',
          'cached_at': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> insertPendingStringItem(String listType, String value) async {
    final db = await database;
    await db.insert('cached_string_list', {
      'list_type': listType, 'value': value, 'sync_status': 'pending',
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> renameStringItem(String listType, String oldValue, String newValue) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_string_list', where: 'list_type = ? AND value = ?', whereArgs: [listType, oldValue]);
      await txn.insert('cached_string_list', {
        'list_type': listType, 'value': newValue, 'sync_status': 'done',
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> renameStringItemPending(String listType, String oldValue, String newValue) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_string_list', where: 'list_type = ? AND value = ?', whereArgs: [listType, oldValue]);
      await txn.insert('cached_string_list', {
        'list_type': listType, 'value': newValue, 'sync_status': 'pending_rename',
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> markStringItemSynced(String listType, String value) async {
    final db = await database;
    await db.update('cached_string_list', {'sync_status': 'done'},
        where: 'list_type = ? AND value = ?', whereArgs: [listType, value]);
  }

  Future<void> deleteStringItem(String listType, String value) async {
    final db = await database;
    await db.delete('cached_string_list', where: 'list_type = ? AND value = ?', whereArgs: [listType, value]);
  }

  Future<List<String>> getStringList(String listType) async {
    final db = await database;
    return (await db.query('cached_string_list', where: 'list_type = ?', whereArgs: [listType], orderBy: 'value ASC'))
        .map((r) => r['value'] as String).toList();
  }

  Future<Set<String>> getPendingDeletedNames(String entityType) async {
    final db = await database;
    final rows = await db.query('pending_ops',
        where: "entity_type = ? AND operation = 'delete' AND status = 'pending'", whereArgs: [entityType]);
    final names = <String>{};
    for (final r in rows) {
      try {
        final payload = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        final name = '${payload['name'] ?? payload['id'] ?? ''}';
        if (name.isNotEmpty) names.add(name);
      } catch (_) {}
    }
    return names;
  }

  Future<Set<String>> getPendingDeletedIds([String entityType = 'student']) async {
    final db = await database;
    final rows = await db.query('pending_ops',
        where: "entity_type = ? AND operation = 'delete' AND status = 'pending'", whereArgs: [entityType]);
    final ids = <String>{};
    for (final r in rows) {
      try {
        final payload = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        final id = '${payload['id'] ?? payload['server_id'] ?? payload['local_id'] ?? ''}';
        if (id.isNotEmpty) ids.add(id);
      } catch (_) {}
    }
    return ids;
  }

  Future<List<String>> getPendingStringItems(String listType) async {
    final db = await database;
    return (await db.query('cached_string_list',
        where: 'list_type = ? AND sync_status != ?', whereArgs: [listType, 'done'], orderBy: 'value ASC'))
        .map((r) => r['value'] as String).toList();
  }

  // ═══════════════════════════════════════
  // PENDING OPERATIONS QUEUE
  // ═══════════════════════════════════════

  Future<void> enqueuePendingOp(String entityType, String operation, Map<String, dynamic> payload, {
    String originalValue = '',
    String previousState = '',
  }) async {
    final db = await database;
    final idempotencyKey = '${entityType}_${operation}_${DateTime.now().millisecondsSinceEpoch}_${payload.hashCode}';
    await db.insert('pending_ops', {
      'entity_type': entityType,
      'operation': operation,
      'payload': jsonEncode(payload),
      'original_value': originalValue,
      'previous_state': previousState,
      'idempotency_key': idempotencyKey,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOps({String? entityType, String status = 'pending'}) async {
    final db = await database;
    String where = 'status = ?';
    List<dynamic> whereArgs = [status];
    if (entityType != null) {
      where += ' AND entity_type = ?';
      whereArgs.add(entityType);
    }
    return await db.query('pending_ops', where: where, whereArgs: whereArgs, orderBy: 'id ASC');
  }

  Future<void> markOpDone(int id) async {
    final db = await database;
    await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markOpFailed(int id, String error, int statusCode) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_ops SET status = ?, last_error = ?, retry_count = retry_count + 1 WHERE id = ?',
      ['failed_permanent', '$statusCode: $error', id],
    );
  }

  Future<void> incrementRetryOp(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_ops SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<void> moveToFailedTable(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('pending_ops', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final row = rows.first;
      await txn.insert('failed_ops', {
        'op_id': row['id'],
        'entity_type': row['entity_type'],
        'operation': row['operation'],
        'payload': row['payload'],
        'previous_state': row['previous_state'] ?? '',
        'error_message': row['last_error'] ?? '',
        'failed_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> renamePendingRefs(String entityType, String oldName, String newName) async {
    final db = await database;
    final ops = await db.query('pending_ops', where: "status = 'pending'");
    for (final op in ops) {
      final payloadStr = op['payload'] as String;
      if (payloadStr.isEmpty) continue;
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(payloadStr) as Map);
        bool changed = false;
        if (entityType == 'section') {
          if (payload['section_name'] == oldName) { payload['section_name'] = newName; changed = true; }
          if (payload['section'] == oldName) { payload['section'] = newName; changed = true; }
        }
        if (entityType == 'subject') {
          if (payload['subject_name'] == oldName) { payload['subject_name'] = newName; changed = true; }
        }
        if (entityType == 'role') {
          if (payload['role_name'] == oldName) { payload['role_name'] = newName; changed = true; }
        }
        if (changed) {
          await db.update('pending_ops', {'payload': jsonEncode(payload)}, where: 'id = ?', whereArgs: [op['id']]);
        }
      } catch (_) {}
    }
  }

  Future<int> getPendingOpCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM pending_ops WHERE status = 'pending'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getFailedOpCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM failed_ops');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getFailedOps() async {
    final db = await database;
    return await db.query('failed_ops', orderBy: 'failed_at DESC');
  }

  Future<void> clearFailedOps() async {
    final db = await database;
    await db.delete('failed_ops');
  }

  // ═══════════════════════════════════════
  // META
  // ═══════════════════════════════════════

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('dashboard_meta', {
      'key': key, 'value': value, 'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('dashboard_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  // ═══════════════════════════════════════
  // FULL WIPE
  // ═══════════════════════════════════════

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cached_students');
      await txn.delete('cached_teachers');
      await txn.delete('cached_staff');
      await txn.delete('cached_string_list');
      await txn.delete('pending_ops');
      await txn.delete('failed_ops');
      await txn.delete('dashboard_meta');
    });
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Map<String, dynamic> _extractExtra(Map<String, dynamic> source, List<String> knownKeys) {
    final extra = <String, dynamic>{};
    for (final entry in source.entries) {
      if (!knownKeys.contains(entry.key)) extra[entry.key] = entry.value;
    }
    return extra;
  }

  Map<String, dynamic> _decodeRow(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    if (out['server_id'] != null && (out['server_id'] as String).isNotEmpty) {
      out['id'] = out['server_id'];
    }
    for (final key in ['extra_fields', 'extra_details']) {
      if (out[key] is String && (out[key] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(out[key]) as Map<String, dynamic>;
          out.remove(key);
          out.addAll(decoded);
        } catch (_) {}
      }
    }
    return out;
  }
}
