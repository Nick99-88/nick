import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'package:starlight_flutter/services/institution//dashboard_service.dart';

class StarlightInteractionEngine {
  static final StarlightVault _vault = StarlightVault.instance;
  static final DashboardService _api = DashboardService();

  /// 🌳 THE STEM: The single point of interaction for the entire Dashboard
  static Future<void> branch({
    required String type,   // 'student', 'teacher', 'staff'
    required String action, // 'admit', 'delete', 'update'
    required Map<String, dynamic> data,
  }) async {
    debugPrint("🏛️ Engine: Branching Interaction [$type -> $action]");

    switch (type) {
      case 'student':
        await _treeStudent(action, data);
        break;
      case 'teacher':
        await _treeTeacher(action, data);
        break;
      case 'staff':
        await _treeStaff(action, data);
        break;
      default:
        debugPrint("⚠️ Engine: Unknown Branch '$type'");
    }
  }

  // ==========================================
  // 🌿 ACTION FILTERS (The Tree Limbs)
  // ==========================================

  static Future<void> _treeStudent(String action, Map<String, dynamic> data) async {
    if (action == 'admit') await _leafStudentAdmit(data);
    // Add future actions like 'promote', 'transfer' here
  }

  static Future<void> _treeTeacher(String action, Map<String, dynamic> data) async {
    if (action == 'admit') await _leafTeacherAdmit(data);
  }

  static Future<void> _treeStaff(String action, Map<String, dynamic> data) async {
    if (action == 'delete') await _leafStaffDelete(data);
  }

  // ==========================================
  // 🍃 THE LEAVES (The Actual Work)
  // ==========================================

  /// 🍃 LEAF: Student Admission
  static Future<void> _leafStudentAdmit(Map<String, dynamic> data) async {
    const String table = 'students';

    try {
      // 1. Force Fetch Server via DashboardService
      debugPrint("📡 Leaf: Contacting Server for Student Admission...");
      await _api.admitStudent(data);

      // 2. Success: Mark as 'done' and store in Vault
      data['sync_status'] = 'done';
    } catch (e) {
      // 3. Fail/Offline: Store in Vault as 'admission_pending'
      debugPrint("📦 Leaf: Server Unreachable. Pivoting to Vault.");
      data['sync_status'] = 'admission_pending';
    }

    await _vault.insertRecord(table, data);
  }

  /// 🍃 LEAF: Teacher Admission
  static Future<void> _leafTeacherAdmit(Map<String, dynamic> data) async {
    const String table = 'teachers';

    try {
      debugPrint("📡 Leaf: Contacting Server for Teacher Admission...");
      // Using generic naming from service logic
      await _api.hireTeacher(data);
      data['sync_status'] = 'done';
    } catch (e) {
      debugPrint("📦 Leaf: Pivoting to Vault as 'teacher_pending'.");
      data['sync_status'] = 'teacher_pending';
    }

    await _vault.insertRecord(table, data);
  }

  /// 🍃 LEAF: Staff Deletion
  static Future<void> _leafStaffDelete(Map<String, dynamic> data) async {
    const String table = 'staff';

    try {
      debugPrint("📡 Leaf: Requesting Staff Deletion from Server...");
      await _api.deleteStaff(data['server_id']);
      data['sync_status'] = 'done';
    } catch (e) {
      debugPrint("📦 Leaf: Marking for deletion in Vault.");
      data['sync_status'] = 'pending_delete';
      data['is_active'] = 0; // Optimistic Hide
    }

    await _vault.insertRecord(table, data);
  }
}