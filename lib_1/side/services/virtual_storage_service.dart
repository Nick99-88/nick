import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/virtual_project.dart';

class VirtualStorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'side_projects.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            language TEXT NOT NULL DEFAULT 'python',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE files (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            name TEXT NOT NULL,
            content TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  static Future<void> saveProject(VirtualProject project) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('projects', {
        'id': project.id,
        'name': project.name,
        'language': project.language,
        'created_at': project.createdAt.toIso8601String(),
        'updated_at': project.updatedAt.toIso8601String(),
        'is_synced': project.isSynced ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('files', where: 'project_id = ?', whereArgs: [project.id]);
      for (final file in project.files) {
        await txn.insert('files', {
          'id': file.id,
          'project_id': project.id,
          'name': file.name,
          'content': file.content,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<List<VirtualProject>> getAllProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'updated_at DESC');
    final projects = <VirtualProject>[];
    for (final row in rows) {
      final files = await db.query('files',
          where: 'project_id = ?', whereArgs: [row['id']]);
      projects.add(_rowToProject(row, files));
    }
    return projects;
  }

  static Future<VirtualProject?> getProject(String id) async {
    final db = await database;
    final rows = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final files = await db.query('files', where: 'project_id = ?', whereArgs: [id]);
    return _rowToProject(rows.first, files);
  }

  static Future<List<VirtualProject>> searchProjects(String query) async {
    final db = await database;
    final lower = query.toLowerCase();
    final rows = await db.query('projects',
        where: 'LOWER(name) LIKE ?', whereArgs: ['%$lower%'],
        orderBy: 'updated_at DESC');
    final projects = <VirtualProject>[];
    for (final row in rows) {
      final files = await db.query('files',
          where: 'project_id = ?', whereArgs: [row['id']]);
      projects.add(_rowToProject(row, files));
    }
    return projects;
  }

  static Future<void> deleteProject(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('files', where: 'project_id = ?', whereArgs: [id]);
      await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> addFile(String projectId, VirtualFile file) async {
    final db = await database;
    await db.insert('files', {
      'id': file.id,
      'project_id': projectId,
      'name': file.name,
      'content': file.content,
    });
    await db.update('projects',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [projectId]);
  }

  static Future<void> updateFile(String projectId, VirtualFile file) async {
    final db = await database;
    await db.update('files',
        {'name': file.name, 'content': file.content},
        where: 'id = ?', whereArgs: [file.id]);
    await db.update('projects',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [projectId]);
  }

  static Future<void> deleteFile(String projectId, String fileId) async {
    final db = await database;
    await db.delete('files', where: 'id = ?', whereArgs: [fileId]);
    await db.update('projects',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [projectId]);
  }

  static Future<void> renameFile(String projectId, String fileId, String newName) async {
    final db = await database;
    await db.update('files', {'name': newName},
        where: 'id = ?', whereArgs: [fileId]);
    await db.update('projects',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [projectId]);
  }

  static Future<void> markSynced(String id) async {
    final db = await database;
    await db.update('projects', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markUnsynced(String id) async {
    final db = await database;
    await db.update('projects', {'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  static VirtualProject _rowToProject(Map<String, dynamic> row, List<Map<String, dynamic>> fileRows) {
    return VirtualProject(
      id: row['id'] as String,
      name: row['name'] as String,
      language: row['language'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isSynced: (row['is_synced'] as int) == 1,
      files: fileRows.map((f) => VirtualFile(
        id: f['id'] as String,
        name: f['name'] as String,
        content: f['content'] as String,
      )).toList(),
    );
  }
}
