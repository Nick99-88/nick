import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class VaultController {
  // --- SYSTEM & INTRO LOGIC ---

  /// ✅ Update intro status to true (1)
  static Future<void> markIntroAsSeen() async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'system_metadata',
      {'is_seen_intro': 1},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 🔍 Check if user has completed intro
  static Future<bool> isIntroCompleted() async {
    final db = await StarlightVault.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'system_metadata',
      columns: ['is_seen_intro'],
      where: 'id = 1',
    );
    return res.isNotEmpty && res.first['is_seen_intro'] == 1;
  }


  // Inside db_functions.dart -> VaultController class

  /// 🎯 Update FCM Token in Vault
  /// Keeps the local identity aligned with the Firebase cloud token
  static Future<void> updateLocalFcmToken(String token) async {
    final db = await StarlightVault.instance.database;

    await db.update(
      'user_identity',
      {'fcm_token': token},
      where: 'id = ?',
      whereArgs: [1], // Targeting the singleton user record
    );

    print("🏛️ Vault: FCM Token persisted locally.");
  }
  // --- USER IDENTITY LOGIC ---

  /// 👤 Save or Update the current user identity
  /// Uses id = 1 to ensure a single-user local session
  static Future<void> saveUserIdentity(Map<String, dynamic> userData) async {
    final db = await StarlightVault.instance.database;

    // Ensure the ID is forced to 1 for the singleton record logic
    final Map<String, dynamic> row = {
      ...userData,
      'id': 1,
      'sync_status': 'done',
    };

    await db.insert(
      'user_identity',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔍 Retrieve the active user identity
  static Future<Map<String, dynamic>?> getUserIdentity() async {
    final db = await StarlightVault.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_identity',
      where: 'id = 1',
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // --- INSTITUTION GENERATOR LOGIC ---

  /// ➕ Generate & Save new institution
  /// Status is false (0) by default
  static Future<void> generateInstitutionApp(String name, String appId) async {
    final db = await StarlightVault.instance.database;
    await db.insert(
      'managed_institutions',
      {
        'institution_name': name,
        'institution_id': appId,
        'is_active': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 📋 Get all institutions ordered by name
  static Future<List<Map<String, dynamic>>> getAllInstitutions() async {
    final db = await StarlightVault.instance.database;
    return await db.query(
      'managed_institutions',
      orderBy: 'institution_name ASC',
    );
  }

  /// 🎯 Select & Activate an Institution
  /// Architecture: Deactivates all apps and activates only the selected one in a single transaction.
  static Future<void> activateInstitution(String appId) async {
    final db = await StarlightVault.instance.database;

    await db.transaction((txn) async {
      // 1. Deactivate all institutions
      await txn.update(
        'managed_institutions',
        {'is_active': 0},
      );

      // 2. Activate the selected one
      await txn.update(
        'managed_institutions',
        {'is_active': 1},
        where: 'institution_id = ?',
        whereArgs: [appId],
      );
    });
  }

  /// 🗑️ Wipe current identity (Logout)
  static Future<void> clearUserSession() async {
    final db = await StarlightVault.instance.database;
    await db.delete('user_identity', where: 'id = 1');
  }
}