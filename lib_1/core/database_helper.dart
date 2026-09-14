import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class StarlightVault {
  static final StarlightVault instance = StarlightVault._init();
  static Database? _database;

  StarlightVault._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('starlight_vault.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute("DROP TABLE IF EXISTS user_identity");
          await _createUserIdentityTable(db);
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS campaign_students (
              id TEXT PRIMARY KEY,
              name TEXT,
              father_name TEXT,
              phone TEXT,
              fee REAL DEFAULT 0,
              section TEXT,
              campaign_id TEXT,
              paid INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS campaign_personnel (
              id TEXT PRIMARY KEY,
              name TEXT,
              designation TEXT,
              phone TEXT,
              salary REAL DEFAULT 0,
              node_type TEXT,
              campaign_id TEXT,
              paid INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS shop_bundles (
              id TEXT PRIMARY KEY,
              type TEXT,
              title TEXT,
              description TEXT,
              price REAL,
              currency TEXT,
              is_popular INTEGER DEFAULT 0,
              products TEXT,
              gold INTEGER DEFAULT 0,
              silver INTEGER DEFAULT 0,
              ai_credits INTEGER DEFAULT 0,
              updated_at TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS library_downloads (
              id TEXT PRIMARY KEY,
              title TEXT,
              author TEXT,
              topic TEXT,
              doc_type TEXT,
              local_path TEXT,
              file_name TEXT,
              file_ext TEXT,
              file_size INTEGER,
              channel_id TEXT,
              channel_name TEXT,
              channel_pic TEXT,
              created_at TEXT
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS shop_bundles (
              id TEXT PRIMARY KEY,
              type TEXT,
              title TEXT,
              description TEXT,
              price REAL,
              currency TEXT,
              is_popular INTEGER DEFAULT 0,
              products TEXT,
              gold INTEGER DEFAULT 0,
              silver INTEGER DEFAULT 0,
              ai_credits INTEGER DEFAULT 0,
              updated_at TEXT
            )
          ''');
        }
      },
    );
  }

  Future _createUserIdentityTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_identity (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT,
        full_name TEXT,
        email TEXT UNIQUE,
        phone_number TEXT,
        role TEXT,
        user_id TEXT,
        fcm_token TEXT,
        institution_id TEXT,
        institution_name TEXT,
        institution_ref TEXT,
        is_active INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'done'
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    const integerType = 'INTEGER';
    const realType = 'REAL';
    const textType = 'TEXT';

    // 1. Metadata Table
    await db.execute('''
    CREATE TABLE system_metadata (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      app_id TEXT,
      app_name TEXT,
      version TEXT,
      is_seen_intro INTEGER DEFAULT 0,
      last_init TEXT
    )
    ''');

    await db.insert('system_metadata', {
      'id': 1,
      'is_seen_intro': 0,
      'version': '1.0.0',
      'last_init': DateTime.now().toIso8601String()
    });

    // 2. Managed Institutions
    await db.execute('''
      CREATE TABLE managed_institutions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        institution_id TEXT UNIQUE,
        institution_name TEXT,
        is_active INTEGER DEFAULT 0
      )
    ''');

    // 3. System Identity
    await _createUserIdentityTable(db);

    // 4. Dashboard Modules
    await db.execute('''
      CREATE TABLE students (
        id $integerType PRIMARY KEY AUTOINCREMENT,
        server_id $integerType UNIQUE,
        local_id $textType UNIQUE,
        name $textType NOT NULL,
        father_name $textType NOT NULL,
        section $textType NOT NULL,
        fee $realType NOT NULL,
        admitted_by $textType,
        extra_fields $textType,
        is_active $integerType DEFAULT 1,
        sync_status $textType DEFAULT 'done'
      )
    ''');

    await db.execute('''
      CREATE TABLE teachers (
        id $integerType PRIMARY KEY AUTOINCREMENT,
        server_id $integerType UNIQUE,
        local_id $textType UNIQUE,
        name $textType NOT NULL,
        subject_expertise $textType,
        phone $textType,
        salary $realType,
        joining_date $textType,
        extra_details $textType,
        is_active $integerType DEFAULT 1,
        sync_status $textType DEFAULT 'done'
      )
    ''');

    await db.execute('''
      CREATE TABLE staff (
        id $integerType PRIMARY KEY AUTOINCREMENT,
        server_id $integerType UNIQUE,
        local_id $textType UNIQUE,
        name $textType NOT NULL,
        position $textType NOT NULL,
        cnic $textType,
        contact $textType,
        extra_details $textType,
        is_active $integerType DEFAULT 1,
        sync_status $textType DEFAULT 'done'
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        subject_name TEXT,
        sections TEXT,
        content_data TEXT,
        is_finalized INTEGER,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE datesheet_vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        exam_title TEXT,
        target_section TEXT,
        entries_json TEXT,
        published_date TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE student_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        student_id TEXT,
        student_name TEXT,
        father_name TEXT,
        attendance_status TEXT,
        attendance_date TEXT,
        section_name TEXT,
        attendance_type TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE staff_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        staff_id TEXT,
        staff_name TEXT,
        department TEXT,
        role TEXT,
        duty_shift TEXT,
        attendance_status TEXT,
        attendance_date TEXT,
        target_section TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE question_bank (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        question_text TEXT,
        question_type TEXT,
        marks INTEGER,
        difficulty TEXT,
        options_json TEXT,
        sub_parts_json TEXT,
        subject TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE fee_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        challan_no TEXT,
        student_id TEXT,
        amount_due REAL,
        due_date TEXT,
        fee_structure_json TEXT,
        is_paid INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE institutional_notices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        notice_title TEXT,
        notice_body TEXT,
        language_code TEXT,
        authorized_by TEXT,
        broadcast_date TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE universal_blueprints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        blueprint_name TEXT,
        columns_config TEXT,
        rows_config TEXT,
        footer_note TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE document_vault (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id TEXT,
        file_name TEXT,
        local_path TEXT,
        file_type TEXT,
        vault_category TEXT,
        last_modified TEXT,
        sync_status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE campaign_students (
        id TEXT PRIMARY KEY,
        name TEXT,
        father_name TEXT,
        phone TEXT,
        fee REAL DEFAULT 0,
        section TEXT,
        campaign_id TEXT,
        paid INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE campaign_personnel (
        id TEXT PRIMARY KEY,
        name TEXT,
        designation TEXT,
        phone TEXT,
        salary REAL DEFAULT 0,
        node_type TEXT,
        campaign_id TEXT,
        paid INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE library_downloads (
        id TEXT PRIMARY KEY,
        title TEXT,
        author TEXT,
        topic TEXT,
        doc_type TEXT,
        local_path TEXT,
        file_name TEXT,
        file_ext TEXT,
        file_size INTEGER,
        channel_id TEXT,
        channel_name TEXT,
        channel_pic TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_bundles (
        id TEXT PRIMARY KEY,
        type TEXT,
        title TEXT,
        description TEXT,
        price REAL,
        currency TEXT,
        is_popular INTEGER DEFAULT 0,
        products TEXT,
        gold INTEGER DEFAULT 0,
        silver INTEGER DEFAULT 0,
        ai_credits INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');
  }

  Future<int> insertRecord(String table, Map<String, dynamic> data) async {
    final db = await instance.database;
    if (data.containsKey('extra_fields')) data['extra_fields'] = jsonEncode(data['extra_fields']);
    if (data.containsKey('extra_details')) data['extra_details'] = jsonEncode(data['extra_details']);
    return await db.insert(table, data);
  }

  Future<dynamic> fetchFieldValue(String table, String columnName, {String? whereKey, dynamic whereValue}) async {
    final db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      table,
      columns: [columnName],
      where: whereKey != null ? '$whereKey = ?' : null,
      whereArgs: whereValue != null ? [whereValue] : null,
    );
    if (maps.isNotEmpty) return maps.first[columnName];
    return null;
  }

  Future<void> smartPurge({required String table, String? columnName, bool wholeTable = false}) async {
    final db = await instance.database;
    if (wholeTable) {
      await db.delete(table);
    } else if (columnName != null) {
      await db.update(table, {columnName: null});
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollection(String table) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query(table);
    return result.map((row) {
      final Map<String, dynamic> mutableRow = Map.from(row);
      mutableRow.forEach((key, value) {
        if (value is String && (value.startsWith('{') || value.startsWith('['))) {
          try { mutableRow[key] = jsonDecode(value); } catch (_) {}
        }
      });
      return mutableRow;
    }).toList();
  }

  Future<void> rehydrateTable(String table, List<Map<String, dynamic>> serverData) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(table, where: 'sync_status = ?', whereArgs: ['done']);
      for (var data in serverData) {
        var mutableData = Map<String, dynamic>.from(data);
        mutableData['sync_status'] = 'done';
        mutableData['server_id'] = mutableData['id'];
        mutableData.remove('id');
        if (mutableData['extra_fields'] != null) mutableData['extra_fields'] = jsonEncode(mutableData['extra_fields']);
        if (mutableData['extra_details'] != null) mutableData['extra_details'] = jsonEncode(mutableData['extra_details']);
        await txn.insert(table, mutableData, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Map<String, dynamic> cleanRow(Map<String, dynamic> row) {
    final Map<String, dynamic> mutableRow = Map.from(row);
    mutableRow.forEach((key, value) {
      if (value is String && (value.startsWith('{') || value.startsWith('['))) {
        try { mutableRow[key] = jsonDecode(value); } catch (_) {}
      }
    });
    return mutableRow;
  }
}
