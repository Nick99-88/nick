import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import '../services/institution/dashboard_service.dart';

class StarlightDataRouter {
  static final StarlightVault _vault = StarlightVault.instance;
  static final DashboardService _api = DashboardService();

  /// 🌳 THE STEM: Central fetcher that tries Server first, then falls back to Vault
  static Future<List<Map<String, dynamic>>> fetch({
    required String type,
    String? section,
  }) async {
    debugPrint("🏛️ Router: Routing request for [$type] | Section: [$section]");

    try {
      // 1. TRY SERVER FIRST
      return await _branchToServer(type, section);
    } catch (e) {
      // 2. FALLBACK TO VAULT (Offline Engine)
      debugPrint("📦 Router: Server fetch failed ($e). Using Offline Vault.");
      return await _branchToVault(type, section);
    }
  }

  // ==========================================
  // 🌿 BRANCH: Server Logic (Strictly Service File)
  // ==========================================
  static Future<List<Map<String, dynamic>>> _branchToServer(String type, String? section) async {
    switch (type) {
      case 'students':
      // FIX: If section is provided, use positional 'getStudentsBySection'
      // Otherwise, use 'getMyStudents' and extract the list.
        if (section != null && section.isNotEmpty) {
          final List<dynamic> data = await _api.getStudentsBySection(section);
          return data.cast<Map<String, dynamic>>();
        } else {
          final Map<String, dynamic> response = await _api.getMyStudents();
          final List<dynamic> data = response['students'] ?? [];
          return data.cast<Map<String, dynamic>>();
        }

      case 'teachers':
      // getTeacherList returns Map<String, dynamic>
        final Map<String, dynamic> response = await _api.getTeacherList();
        final List<dynamic> teacherData = response['teachers'] ?? [];
        return teacherData.cast<Map<String, dynamic>>();

      case 'staff':
      // getStaffList returns Map<String, dynamic>
        final Map<String, dynamic> response = await _api.getStaffList();
        final List<dynamic> staffData = response['staff'] ?? [];
        return staffData.cast<Map<String, dynamic>>();

      default:
        throw Exception("Unknown data type: $type");
    }
  }

  // ==========================================
  // 🌿 BRANCH: Vault Logic (Offline Filter)
  // ==========================================
  static Future<List<Map<String, dynamic>>> _branchToVault(String type, String? section) async {
    final db = await _vault.database;

    // Logic: Filter by active status and section if applicable
    String whereClause = 'is_active = ?';
    List<dynamic> whereArgs = [1];

    if (type == 'students' && section != null) {
      whereClause += ' AND section = ?';
      whereArgs.add(section);
    }

    // SQLite Table naming consistency
    String tableName = type;
    if (type == 'teachers') tableName = 'teachers';

    final List<Map<String, dynamic>> results = await db.query(
      tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );

    return results;
  }
}