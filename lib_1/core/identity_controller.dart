import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class IdentityController {

  // --- CORE IDENTITY MANAGEMENT ---

  /// 🛠️ SAVE/UPDATE BULK: The "Upsert" Engine
  static Future<void> setFullIdentity(Map<String, dynamic> data) async {
    final db = await StarlightVault.instance.database;

    Map<String, dynamic> identityData = {'id': 1};

    // Map only known SQLite columns
    if (data['email'] != null) identityData['email'] = data['email'];
    if (data['name'] != null) identityData['name'] = data['name'];
    if (data['full_name'] != null) identityData['full_name'] = data['full_name'];
    if (data['role'] != null) identityData['role'] = data['role'];
    if (data['role_id'] != null) identityData['user_id'] = data['role_id'].toString();
    if (data['phone'] != null) identityData['phone_number'] = data['phone'];
    if (data['phone_number'] != null) identityData['phone_number'] = data['phone_number'];
    if (data['institution_id'] != null) identityData['institution_id'] = data['institution_id'].toString();
    if (data['is_active'] != null) {
      identityData['is_active'] = data['is_active'] is int
          ? data['is_active']
          : (data['is_active'] == true ? 1 : 0);
    }

    await db.insert(
      'user_identity',
      identityData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> saveLoginSession(Map<String, dynamic> userData) async {
    final db = await StarlightVault.instance.database;

    Map<String, dynamic> cleanData = Map.from(userData);
    cleanData['id'] = 1;

    await db.insert(
      'user_identity',
      cleanData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🎯 UPDATE SPECIFIC: The "Precision" Engine
  static Future<void> updateField(String key, dynamic value) async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'user_identity',
      {key: value.toString()}, // Ensure value is stored as string in TEXT column
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 🔍 GET SPECIFIC
  static Future<dynamic> getField(String key) async {
    final db = await StarlightVault.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'user_identity',
      columns: [key],
      where: 'id = ?',
      whereArgs: [1],
    );

    if (res.isNotEmpty) {
      return res.first[key];
    }
    return null;
  }

  /// 📋 GET FULL
  static Future<Map<String, dynamic>?> getIdentity() async {
    final db = await StarlightVault.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'user_identity',
      where: 'id = ?',
      whereArgs: [1],
    );

    return res.isNotEmpty ? res.first : null;
  }

  static Future<void> updateRoleInfo({
    required String role,
    required String roleId,
  }) async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'user_identity',
      {
        'role': role,
        'user_id': roleId,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 🏛️ INSTITUTIONAL LINKING
  /// Links the identity to a specific institution after role solidification
  static Future<void> linkInstitution({
    required String name,
    required String ref,
    required String id, // 🏛️ FIXED: Changed from int to String to match 'com.starlight.abc' format
  }) async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'user_identity',
      {
        'institution_name': name,
        'institution_ref': ref,
        'institution_id': id,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }


  // --- BRANDING & CONTEXT HELPERS ---

  /// 🏛️ Get current Institution Branding
  static Future<Map<String, String>> getInstitutionBranding() async {
    final db = await StarlightVault.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'user_identity',
      columns: ['institution_name', 'institution_ref'],
      where: 'id = 1',
    );

    if (res.isNotEmpty) {
      return {
        'name': res.first['institution_name'] ?? 'Starlight Institution',
        'ref': res.first['institution_ref'] ?? 'starlight-gen-00',
      };
    }
    return {'name': 'Starlight Institution', 'ref': 'starlight-gen-00'};
  }

  /// 🗑️ WIPE IDENTITY: Logout / Session Clear
  static Future<void> clearIdentity() async {
    final db = await StarlightVault.instance.database;
    await db.delete('user_identity', where: 'id = 1');
  }

  /// 🏛️ SYSTEM BRANDING LOCK
  static Future<void> lockInstitutionalIdentity({
    required String name,
    required String id,
    required String ref,
  }) async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'user_identity',
      {
        'institution_name': name,
        'institution_id': id,
        'institution_ref': ref,
        'sync_status': 'done',
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}