import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database_helper.dart';

class StudentAttendanceRouter {
  static final StarlightVault _vault = StarlightVault.instance;

  /// 📥 Insert/Save a student attendance session (Batch insert)
  static Future<void> saveAttendanceSession({
    required String sectionName,
    required String date,
    required String attendanceType, // 'class' or 'test'
    required List<Map<String, dynamic>> records,
  }) async {
    final db = await _vault.database;
    await db.transaction((txn) async {
      for (var record in records) {
        await txn.insert(
          'student_attendance',
          {
            'student_id': record['student_id'],
            'student_name': record['student_name'],
            'father_name': record['father_name'] ?? '',
            'attendance_status': record['status'],
            'attendance_date': date,
            'section_name': sectionName,
            'attendance_type': attendanceType,
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 🔍 Fetch student attendance records by section and date
  static Future<List<Map<String, dynamic>>> fetchAttendance({
    required String sectionName,
    required String date,
  }) async {
    final db = await _vault.database;
    return await db.query(
      'student_attendance',
      where: 'section_name = ? AND attendance_date = ?',
      whereArgs: [sectionName, date],
    );
  }

  /// 📊 Get student attendance stats for a specific date
  static Future<Map<String, int>> getStatsForDate(String date) async {
    final db = await _vault.database;
    final List<Map<String, dynamic>> results = await db.query(
      'student_attendance',
      where: 'attendance_date = ?',
      whereArgs: [date],
    );

    int present = 0;
    int absent = 0;
    int lateCount = 0;

    for (var r in results) {
      final status = r['attendance_status']?.toString().toUpperCase();
      if (status == 'P' || status == 'PRESENT') present++;
      if (status == 'A' || status == 'ABSENT') absent++;
      if (status == 'L' || status == 'LATE') lateCount++;
    }

    return {
      'total': results.length,
      'present': present,
      'absent': absent,
      'late': lateCount,
    };
  }

  /// 🔄 Get all pending student attendance records to sync to cloud
  static Future<List<Map<String, dynamic>>> getPendingSyncRecords() async {
    final db = await _vault.database;
    return await db.query(
      'student_attendance',
      where: "sync_status = 'pending'",
    );
  }

  /// Mark records as synced with the backend server
  static Future<void> markAsSynced(List<int> ids, {String? serverSessionId}) async {
    final db = await _vault.database;
    await db.transaction((txn) async {
      for (var id in ids) {
        await txn.update(
          'student_attendance',
          {
            'sync_status': 'done',
            if (serverSessionId != null) 'server_id': serverSessionId,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// 🏛️ Save Sheet Blueprint specifically for Student Attendance
  static Future<int> saveStudentAttendanceBlueprint({
    required String title,
    required List<Map<String, dynamic>> columns,
    required List<Map<String, dynamic>> rows,
    required String footerNote,
  }) async {
    final db = await _vault.database;
    return await db.insert(
      'universal_blueprints',
      {
        'blueprint_name': title,
        'columns_config': jsonEncode(columns),
        'rows_config': jsonEncode(rows),
        'footer_note': footerNote,
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔍 Fetch latest Student Attendance Blueprint
  static Future<Map<String, dynamic>?> getLatestBlueprint() async {
    final db = await _vault.database;
    final List<Map<String, dynamic>> results = await db.query(
      'universal_blueprints',
      where: "blueprint_name LIKE '%student%' OR blueprint_name LIKE '%Student%'",
      orderBy: 'id DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final bp = results.first;
    return {
      'id': bp['id'],
      'server_id': bp['server_id'],
      'title': bp['blueprint_name'],
      'columns': jsonDecode(bp['columns_config'] ?? '[]'),
      'rows': jsonDecode(bp['rows_config'] ?? '[]'),
      'footer_note': bp['footer_note'],
      'sync_status': bp['sync_status'],
    };
  }
}
