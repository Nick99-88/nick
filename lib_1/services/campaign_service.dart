import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';

class CampaignService {
  static final CampaignService instance = CampaignService._();

  CampaignService._();

  Future<Database> get _db => StarlightVault.instance.database;

  Future<void> saveStudentCampaign(String campaignId, List<Map<String, dynamic>> sections) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('campaign_students', where: 'campaign_id = ?', whereArgs: [campaignId]);
      for (final sec in sections) {
        final sectionName = sec['section_name'] as String? ?? '';
        for (final s in sec['students'] as List<dynamic>) {
          final student = s as Map<String, dynamic>;
          await txn.insert('campaign_students', {
            'id': student['id'],
            'name': student['name'] ?? '',
            'father_name': student['father_name'] ?? '',
            'phone': student['phone'] ?? '',
            'fee': (student['fee'] ?? 0).toDouble(),
            'section': sectionName,
            'campaign_id': campaignId,
            'paid': student['paid'] == true ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> savePersonnelCampaign(String campaignId, List<Map<String, dynamic>> personnel) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('campaign_personnel', where: 'campaign_id = ?', whereArgs: [campaignId]);
      for (final p in personnel) {
        await txn.insert('campaign_personnel', {
          'id': p['id'],
          'name': p['name'] ?? '',
          'designation': p['designation'] ?? '',
          'phone': p['phone'] ?? '',
          'salary': (p['salary'] ?? 0).toDouble(),
          'node_type': p['node_type'] ?? '',
          'campaign_id': campaignId,
          'paid': p['paid'] == true ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getStudentsByCampaign(String campaignId) async {
    final db = await _db;
    return db.query('campaign_students', where: 'campaign_id = ?', whereArgs: [campaignId]);
  }

  Future<List<Map<String, dynamic>>> getPersonnelByCampaign(String campaignId) async {
    final db = await _db;
    return db.query('campaign_personnel', where: 'campaign_id = ?', whereArgs: [campaignId]);
  }

  Future<List<Map<String, dynamic>>> getStudentsBySection(String campaignId, String section) async {
    final db = await _db;
    return db.query('campaign_students',
        where: 'campaign_id = ? AND section = ?', whereArgs: [campaignId, section]);
  }

  Future<List<String>> getSections(String campaignId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT DISTINCT section FROM campaign_students WHERE campaign_id = ? ORDER BY section',
        [campaignId]);
    return rows.map((r) => r['section'] as String).toList();
  }

  Future<void> syncStudentCampaign(String campaignId, List<Map<String, dynamic>> serverSections) async {
    await saveStudentCampaign(campaignId, serverSections);
  }

  Future<void> clearCampaign(String campaignId) async {
    final db = await _db;
    await db.delete('campaign_students', where: 'campaign_id = ?', whereArgs: [campaignId]);
    await db.delete('campaign_personnel', where: 'campaign_id = ?', whereArgs: [campaignId]);
  }
}
