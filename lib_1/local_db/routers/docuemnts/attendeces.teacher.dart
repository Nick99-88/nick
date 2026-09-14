import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database_helper.dart';

class TeacherAttendanceRouter {
  static final StarlightVault _vault = StarlightVault.instance;

  /// 📥 Insert/Save a staff/teacher attendance session (Batch insert)
  static Future<void> saveAttendanceSession({
    required String date,
    required String dutyShift, // 'Morning', 'Noon', 'Evening'
    required List<Map<String, dynamic>> records,
  }) async {
    final db = await _vault.database;
    await db.transaction((txn) async {
      for (var record in records) {
        await txn.insert(
          'staff_attendance',
          {
            'staff_id': record['staff_id'],
            'staff_name': record['staff_name'],
            'department': record['department'] ?? 'General',
            'role': record['role'] ?? 'CLASS TEACHER',
            'duty_shift': dutyShift,
            'attendance_status': record['status'],
            'attendance_date': date,
            'target_section': record['target_section'] ?? '',
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 🔍 Fetch staff attendance records by date and shift
  static Future<List<Map<String, dynamic>>> fetchAttendance({
    required String date,
    String? shift,
  }) async {
    final db = await _vault.database;
    if (shift != null) {
      return await db.query(
        'staff_attendance',
        where: 'attendance_date = ? AND duty_shift = ?',
        whereArgs: [date, shift],
      );
    } else {
      return await db.query(
        'staff_attendance',
        where: 'attendance_date = ?',
        whereArgs: [date],
      );
    }
  }

  /// 📊 Get staff attendance stats for a specific date
  static Future<Map<String, int>> getStatsForDate(String date) async {
    final db = await _vault.database;
    final List<Map<String, dynamic>> results = await db.query(
      'staff_attendance',
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

  /// 🔄 Get all pending staff attendance records to sync to cloud
  static Future<List<Map<String, dynamic>>> getPendingSyncRecords() async {
    final db = await _vault.database;
    return await db.query(
      'staff_attendance',
      where: "sync_status = 'pending'",
    );
  }

  /// Mark records as synced with backend server
  static Future<void> markAsSynced(List<int> ids, {String? serverSessionId}) async {
    final db = await _vault.database;
    await db.transaction((txn) async {
      for (var id in ids) {
        await txn.update(
          'staff_attendance',
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

  /// 🏛️ Save Sheet Blueprint specifically for Staff/Teacher Attendance
  static Future<int> saveStaffAttendanceBlueprint({
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

  /// 🔍 Fetch latest Staff/Teacher Attendance Blueprint
  static Future<Map<String, dynamic>?> getLatestBlueprint() async {
    final db = await _vault.database;
    final List<Map<String, dynamic>> results = await db.query(
      'universal_blueprints',
      where: "blueprint_name LIKE '%staff%' OR blueprint_name LIKE '%Staff%' OR blueprint_name LIKE '%teacher%'",
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
