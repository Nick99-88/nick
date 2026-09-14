import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../services/institution/dashboard_service.dart';
import 'dashboard_local_db.dart';
import 'dashboard_sync_service.dart';

class DashboardCacheService {
  final DashboardService _api = DashboardService();
  final DashboardLocalDb _db = DashboardLocalDb.instance;

  static final DashboardCacheService instance = DashboardCacheService._();
  DashboardCacheService._();

  // ═══════════════════════════════════════
  // STUDENTS
  // ═══════════════════════════════════════

  Future<Map<String, dynamic>> getMyStudents({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getStudents();
      if (cached.isNotEmpty) {
        final pendingDeleted = await _db.getPendingDeletedIds();
        final filtered = cached.where((s) => !pendingDeleted.contains('${s['server_id']}') && !pendingDeleted.contains('${s['local_id']}')).toList();
        return {'students': filtered};
      }
    }
    try {
      final dynamic data = await _api.getMyStudents();
      List<dynamic> students;
      if (data is List) {
        students = data;
      } else if (data is Map) {
        final dynamic extracted = data['students'] ?? data['rows'];
        students = extracted is List ? extracted : <dynamic>[];
      } else {
        students = <dynamic>[];
      }
      final pendingDeleted = await _db.getPendingDeletedIds();
      final filtered = students.where((s) => !pendingDeleted.contains('${s['id'] ?? s['server_id'] ?? ''}') && !pendingDeleted.contains('${s['local_id'] ?? ''}')).toList();
      await _db.replaceStudents(filtered);
      return {'students': filtered};
    } catch (e) {
      debugPrint('🏛️ Cache: getMyStudents failed — $e');
      final cached = await _db.getStudents();
      final pendingDeleted = await _db.getPendingDeletedIds();
      final filtered = cached.where((s) => !pendingDeleted.contains('${s['server_id']}') && !pendingDeleted.contains('${s['local_id']}')).toList();
      if (filtered.isNotEmpty) return {'students': filtered};
      rethrow;
    }
  }

  Future<List<dynamic>> getStudentsBySection(String section, {bool forceRefresh = false}) async {
    final pendingDeleted = await _db.getPendingDeletedIds();
    if (!forceRefresh) {
      final cached = await _db.getStudents(sectionFilter: section);
      final filtered = cached.where((s) => !pendingDeleted.contains('${s['server_id']}') && !pendingDeleted.contains('${s['local_id']}')).toList();
      if (filtered.isNotEmpty) return filtered;
    }
    try {
      final dynamic data = await _api.getStudentsBySection(section);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map) {
        final dynamic extracted = data['students'] ?? data['rows'];
        list = extracted is List ? extracted : <dynamic>[];
      } else {
        list = <dynamic>[];
      }
      final filtered = list.where((s) => !pendingDeleted.contains('${s['id'] ?? s['server_id'] ?? ''}') && !pendingDeleted.contains('${s['local_id'] ?? ''}')).toList();
      await _db.upsertStudentSection(filtered, section);
      return filtered;
    } catch (e) {
      debugPrint('🏛️ Cache: getStudents/$section failed — $e');
      final cached = await _db.getStudents(sectionFilter: section);
      return cached.where((s) => !pendingDeleted.contains('${s['server_id']}') && !pendingDeleted.contains('${s['local_id']}')).toList();
    }
  }

  Future<Map<String, dynamic>> admitStudent(Map<String, dynamic> payload) async {
    try {
      final resp = await _api.admitStudent(payload);
      final student = resp['student'];
      if (student is Map<String, dynamic>) {
        await _db.upsertStudentFromServer(student);
      }
      return {'success': true, 'pending': false, 'student': student};
    } catch (e) {
      debugPrint('🏛️ Cache: admitStudent offline — $e');
      final localId = await _db.insertPendingStudent(payload);
      await _db.enqueuePendingOp('student', 'admit', {...payload, 'local_id': localId});
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> editStudent(String id, Map<String, dynamic> data) async {
    try {
      await _api.editStudent(id, data);
      await _db.updateStudentRow(id, data, syncStatus: 'done');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: editStudent offline — $e');
      final existing = await _db.getStudents();
      final match = existing.where((s) => '${s['server_id']}' == id || '${s['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      await _db.updateStudentRow(id, data, syncStatus: 'pending');
      await _db.enqueuePendingOp('student', 'edit', {...data, 'id': id}, previousState: previousState);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteStudent(String id) async {
    try {
      await _api.deleteStudent(id);
      await _db.deleteStudentById(id);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteStudent offline — $e');
      final existing = await _db.getStudents();
      final match = existing.where((s) => '${s['server_id']}' == id || '${s['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      final serverId = match.isNotEmpty ? '${match.first['server_id']}' : id;
      final localId = match.isNotEmpty ? '${match.first['local_id']}' : '';
      await _db.enqueuePendingOp('student', 'delete', {'id': id, 'server_id': serverId, 'local_id': localId}, previousState: previousState);
      await _db.deleteStudentById(id);
      return {'success': true, 'pending': true};
    }
  }

  Future<String> regenerateStudentKey(String id) async {
    final key = await _api.regenerateStudentKey(id);
    await _db.updateStudentRow(id, {'access_key': key}, syncStatus: 'done');
    return key;
  }

  // ═══════════════════════════════════════
  // TEACHERS
  // ═══════════════════════════════════════

  Future<Map<String, dynamic>> getTeacherList({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getTeachers();
      if (cached.isNotEmpty) return {'teachers': await _removePendingDeleted('teacher', cached)};
    }
    try {
      final data = await _api.getTeacherList();
      final teachers = _extractList(data);
      await _db.replaceTeachers(teachers);
      return {'teachers': teachers};
    } catch (e) {
      debugPrint('🏛️ Cache: getTeacherList failed — $e');
      final cached = await _db.getTeachers();
      if (cached.isNotEmpty) return {'teachers': await _removePendingDeleted('teacher', cached)};
      rethrow;
    }
  }

  Future<List<dynamic>> _removePendingDeleted(String entityType, List<dynamic> rows) async {
    final deleted = await _db.getPendingDeletedIds(entityType);
    if (deleted.isEmpty) return rows;
    return rows.where((r) {
      final id = '${r['server_id'] ?? ''}';
      final local = '${r['local_id'] ?? ''}';
      return !deleted.contains(id) && !deleted.contains(local);
    }).toList();
  }

  List<dynamic> _filterTeachersBySubject(List<dynamic> teachers, String subject) {
    final q = subject.toLowerCase();
    return teachers.where((t) {
      final subj = (t['subject_name'] ?? t['subject_expertise'] ?? '').toString().toLowerCase();
      final desig = (t['designation'] ?? '').toString().toLowerCase();
      return subj.contains(q) || desig.contains(q);
    }).toList();
  }

  Future<List<dynamic>> getTeachersBySubject(String subject, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getTeachers();
      if (cached.isNotEmpty) {
        final filtered = await _removePendingDeleted('teacher', _filterTeachersBySubject(cached, subject));
        if (filtered.isNotEmpty) return filtered;
      }
    }
    try {
      final data = await _api.getTeachersBySubject(subject);
      await _db.replaceTeachers(List.from(data));
      return await _removePendingDeleted('teacher', List.from(data));
    } catch (e) {
      debugPrint('🏛️ Cache: getTeachers/$subject failed — $e');
      final cached = await _db.getTeachers();
      return await _removePendingDeleted('teacher', _filterTeachersBySubject(cached, subject));
    }
  }

  Future<Map<String, dynamic>> hireTeacher(Map<String, dynamic> payload) async {
    try {
      await _api.hireTeacher(payload);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: hireTeacher offline — $e');
      await _db.insertPendingTeacher(payload);
      await _db.enqueuePendingOp('teacher', 'hire', payload);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> updateTeacher(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateTeacher(id, data);
      await _db.updateTeacherRow(id, data, syncStatus: 'done');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: updateTeacher offline — $e');
      final existing = await _db.getTeachers();
      final match = existing.where((t) => '${t['server_id']}' == id || '${t['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      await _db.updateTeacherRow(id, data, syncStatus: 'pending');
      await _db.enqueuePendingOp('teacher', 'update', {...data, 'id': id}, previousState: previousState);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteTeacher(String id) async {
    debugPrint('🏛️ Cache: deleteTeacher called — id=$id');
    try {
      await _api.deleteTeacher(id);
      await _db.deleteTeacherById(id);
      debugPrint('🏛️ Cache: deleteTeacher online — removed id=$id from cache');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteTeacher offline — $e');
      final existing = await _db.getTeachers();
      final match = existing.where((t) => '${t['server_id']}' == id || '${t['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      final serverId = match.isNotEmpty ? '${match.first['server_id']}' : id;
      final localId = match.isNotEmpty ? '${match.first['local_id']}' : '';
      await _db.enqueuePendingOp('teacher', 'delete', {'id': id, 'server_id': serverId, 'local_id': localId}, previousState: previousState);
      await _db.deleteTeacherById(id);
      debugPrint('🏛️ Cache: deleteTeacher offline — queued op + removed id=$id (server_id=$serverId, local_id=$localId)');
      return {'success': true, 'pending': true};
    }
  }

  Future<String> regenerateTeacherKey(String id) async {
    final key = await _api.regenerateTeacherKey(id);
    await _db.updateTeacherRow(id, {'access_key': key}, syncStatus: 'done');
    return key;
  }

  // ═══════════════════════════════════════
  // STAFF
  // ═══════════════════════════════════════

  Future<Map<String, dynamic>> getStaffList({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getStaff();
      if (cached.isNotEmpty) return {'staff': await _removePendingDeleted('staff', cached)};
    }
    try {
      final data = await _api.getStaffList();
      final staff = _extractList(data);
      await _db.replaceStaff(staff);
      return {'staff': staff};
    } catch (e) {
      debugPrint('🏛️ Cache: getStaffList failed — $e');
      final cached = await _db.getStaff();
      if (cached.isNotEmpty) return {'staff': await _removePendingDeleted('staff', cached)};
      rethrow;
    }
  }

  List<dynamic> _filterStaffByRole(List<dynamic> staff, String role) {
    final q = role.toLowerCase();
    return staff.where((s) {
      final pos = (s['position'] ?? '').toString().toLowerCase();
      final roleName = (s['role_name'] ?? s['role'] ?? '').toString().toLowerCase();
      return pos.contains(q) || roleName.contains(q);
    }).toList();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ['rows', 'teachers', 'staff', 'students', 'data']) {
        final v = data[key];
        if (v is List) return v;
      }
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> getStaffByRole(String role, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getStaff();
      if (cached.isNotEmpty) {
        final filtered = await _removePendingDeleted('staff', _filterStaffByRole(cached, role));
        if (filtered.isNotEmpty) return filtered;
      }
    }
    try {
      final data = await _api.getStaffByRole(role);
      await _db.replaceStaff(List.from(data));
      return await _removePendingDeleted('staff', List.from(data));
    } catch (e) {
      debugPrint('🏛️ Cache: getStaff/$role failed — $e');
      final cached = await _db.getStaff();
      return await _removePendingDeleted('staff', _filterStaffByRole(cached, role));
    }
  }

  Future<Map<String, dynamic>> hireStaff(Map<String, dynamic> payload) async {
    try {
      await _api.hireStaff(payload);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: hireStaff offline — $e');
      await _db.insertPendingStaff(payload);
      await _db.enqueuePendingOp('staff', 'hire', payload);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      await _api.updateStaff(id, data);
      await _db.updateStaffRow(id, data, syncStatus: 'done');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: updateStaff offline — $e');
      final existing = await _db.getStaff();
      final match = existing.where((s) => '${s['server_id']}' == id || '${s['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      await _db.updateStaffRow(id, data, syncStatus: 'pending');
      await _db.enqueuePendingOp('staff', 'update', {...data, 'id': id}, previousState: previousState);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteStaff(String id) async {
    debugPrint('🏛️ Cache: deleteStaff called — id=$id');
    try {
      await _api.deleteStaff(id);
      await _db.deleteStaffById(id);
      debugPrint('🏛️ Cache: deleteStaff online — removed id=$id from cache');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteStaff offline — $e');
      final existing = await _db.getStaff();
      final match = existing.where((s) => '${s['server_id']}' == id || '${s['local_id']}' == id);
      final previousState = match.isNotEmpty ? jsonEncode(match.first) : '';
      final serverId = match.isNotEmpty ? '${match.first['server_id']}' : id;
      final localId = match.isNotEmpty ? '${match.first['local_id']}' : '';
      await _db.enqueuePendingOp('staff', 'delete', {'id': id, 'server_id': serverId, 'local_id': localId}, previousState: previousState);
      await _db.deleteStaffById(id);
      debugPrint('🏛️ Cache: deleteStaff offline — queued op + removed id=$id (server_id=$serverId, local_id=$localId)');
      return {'success': true, 'pending': true};
    }
  }

  Future<String> regenerateStaffKey(String id) async {
    final key = await _api.regenerateStaffKey(id);
    await _db.updateStaffRow(id, {'access_key': key}, syncStatus: 'done');
    return key;
  }

  // ═══════════════════════════════════════
  // SECTION ↔ TEACHER ASSIGNMENTS
  // ═══════════════════════════════════════

  // Returns full teacher records (with name + assigned_subject) for a section,
  // joined from the locally cached teacher roster so it works offline.
  Future<List<dynamic>> getSectionTeachers(String section) async {
    final cached = await _db.getSectionTeachers(section);
    if (cached.isNotEmpty) return await _joinTeacherDetails(cached);
    try {
      final data = await _api.getSectionTeachers(section);
      await _db.replaceSectionTeachers(section, data);
      return data;
    } catch (e) {
      debugPrint('🏛️ Cache: getSectionTeachers failed — $e');
      return await _joinTeacherDetails(cached);
    }
  }

  Future<List<dynamic>> _joinTeacherDetails(List<dynamic> assignments) async {
    // Build a quick lookup of teacher id -> teacher record from the cached roster.
    final roster = <String, Map<String, dynamic>>{};
    for (final t in await _db.getTeachers()) {
      roster['${t['server_id'] ?? t['local_id']}'] = t;
    }
    return assignments.map((a) {
      final id = '${a['teacher_id']}';
      final teacher = roster[id] ?? <String, dynamic>{};
      return {
        'id': id,
        'name': teacher['name'] ?? '',
        'designation': teacher['designation'] ?? teacher['subject_expertise'] ?? '',
        'phone': teacher['phone'] ?? '',
        'subject_name': teacher['subject_name'] ?? teacher['subject_expertise'] ?? '',
        'assigned_subject': a['subject_name'] ?? '',
        'sync_status': a['sync_status'] ?? 'done',
      };
    }).toList();
  }

  Future<List<dynamic>> getTeacherSections(String teacherId) async {
    final cached = await _db.getTeacherSections(teacherId);
    if (cached.isNotEmpty) {
      final seen = <String>{};
      final result = <Map<String, dynamic>>[];
      for (final row in cached) {
        final name = '${row['section_name']}';
        if (name.isNotEmpty && seen.add(name)) result.add({'section_name': name});
      }
      return result;
    }
    try {
      final data = await _api.getTeacherSections(teacherId);
      await _db.replaceTeacherSections(teacherId, data);
      return data;
    } catch (e) {
      debugPrint('🏛️ Cache: getTeacherSections failed — $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> assignTeacherToSection(String teacherId, String section, String subject) async {
    try {
      await _api.assignTeacherToSection(teacherId, section, subject);
      await _db.insertSectionTeacher(section, teacherId, subject, syncStatus: 'done');
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: assignTeacherToSection offline — $e');
      await _db.insertSectionTeacher(section, teacherId, subject, syncStatus: 'pending');
      await _db.enqueuePendingOp('section_teacher', 'assign', {
        'teacher_id': teacherId,
        'section_name': section,
        'subject_name': subject,
      });
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> removeTeacherFromSection(String teacherId, String section, String subject) async {
    try {
      await _api.removeTeacherFromSection(section, teacherId, subject);
      await _db.deleteSectionTeacher(section, teacherId, subject);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: removeTeacherFromSection offline — $e');
      await _db.deleteSectionTeacher(section, teacherId, subject);
      await _db.enqueuePendingOp('section_teacher', 'unassign', {
        'teacher_id': teacherId,
        'section_name': section,
        'subject_name': subject,
      });
      return {'success': true, 'pending': true};
    }
  }

  // ═══════════════════════════════════════
  // SECTIONS / SUBJECTS / ROLES (string lists)
  // ═══════════════════════════════════════

  Future<List<String>> getSections({bool forceRefresh = false}) => _getStringList('sections', _api.getSections, forceRefresh);
  Future<List<String>> getSubjects({bool forceRefresh = false}) => _getStringList('subjects', _api.getSubjects, forceRefresh);
  Future<List<String>> getRoles({bool forceRefresh = false}) => _getStringList('roles', _api.getRoles, forceRefresh);

  Future<List<String>> _getStringList(String listType, Future<List<String>> Function() apiCall, bool forceRefresh) async {
    final entityType = listType == 'sections'
        ? 'section'
        : listType == 'subjects'
            ? 'subject'
            : 'role';
    final pendingDeleted = await _db.getPendingDeletedNames(entityType);
    if (!forceRefresh) {
      final cached = await _db.getStringList(listType);
      final filtered = cached.where((s) => !pendingDeleted.contains(s)).toList();
      if (filtered.isNotEmpty) return filtered;
    }
    try {
      final data = await apiCall();
      final filtered = data.where((s) => !pendingDeleted.contains(s)).toList();
      await _db.replaceStringList(listType, filtered);
      return filtered;
    } catch (e) {
      debugPrint('🏛️ Cache: $listType failed — $e');
      final cached = await _db.getStringList(listType);
      return cached.where((s) => !pendingDeleted.contains(s)).toList();
    }
  }

  Future<Map<String, dynamic>> renameSection(String oldName, String newName) async {
    try {
      await _api.renameSection(oldName, newName);
      await _db.renameStringItem('sections', oldName, newName);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: renameSection offline — $e');
      await _db.renameStringItemPending('sections', oldName, newName);
      await _db.enqueuePendingOp('section', 'rename', {'old_name': oldName, 'new_name': newName}, originalValue: oldName);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteSection(String name) async {
    try {
      await _api.deleteSection(name);
      await _db.deleteStringItem('sections', name);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteSection offline — $e');
      await _db.deleteStringItem('sections', name);
      await _db.enqueuePendingOp('section', 'delete', {'name': name}, originalValue: name, previousState: name);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> renameSubject(String oldName, String newName) async {
    try {
      await _api.renameSubject(oldName, newName);
      await _db.renameStringItem('subjects', oldName, newName);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: renameSubject offline — $e');
      await _db.renameStringItemPending('subjects', oldName, newName);
      await _db.enqueuePendingOp('subject', 'rename', {'old_name': oldName, 'new_name': newName}, originalValue: oldName);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteSubject(String name) async {
    try {
      await _api.deleteSubject(name);
      await _db.deleteStringItem('subjects', name);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteSubject offline — $e');
      await _db.deleteStringItem('subjects', name);
      await _db.enqueuePendingOp('subject', 'delete', {'name': name}, originalValue: name, previousState: name);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteSubjects(List<String> names) async {
    int successCount = 0;
    for (final name in names) {
      final result = await deleteSubject(name);
      if (result['success'] == true) successCount++;
    }
    return {'success': successCount > 0, 'pending': successCount < names.length};
  }

  Future<Map<String, dynamic>> renameRole(String oldName, String newName) async {
    try {
      await _api.renameRole(oldName, newName);
      await _db.renameStringItem('roles', oldName, newName);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: renameRole offline — $e');
      await _db.renameStringItemPending('roles', oldName, newName);
      await _db.enqueuePendingOp('role', 'rename', {'old_name': oldName, 'new_name': newName}, originalValue: oldName);
      return {'success': true, 'pending': true};
    }
  }

  Future<Map<String, dynamic>> deleteRole(String name) async {
    try {
      await _api.deleteRole(name);
      await _db.deleteStringItem('roles', name);
      return {'success': true, 'pending': false};
    } catch (e) {
      debugPrint('🏛️ Cache: deleteRole offline — $e');
      await _db.deleteStringItem('roles', name);
      await _db.enqueuePendingOp('role', 'delete', {'name': name}, originalValue: name, previousState: name);
      return {'success': true, 'pending': true};
    }
  }

  // ═══════════════════════════════════════
  // SEARCH (local only)
  // ═══════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchStudentsLocal(String query) => _db.searchStudents(query);

  // ═══════════════════════════════════════
  // PENDING STATUS
  // ═══════════════════════════════════════

  Future<int> getPendingOpCount() => _db.getPendingOpCount();
  Future<List<Map<String, dynamic>>> getPendingOps({String? entityType}) => _db.getPendingOps(entityType: entityType);

  // ═══════════════════════════════════════
  // FAILED OPS (permanent failures)
  // ═══════════════════════════════════════

  Future<int> getFailedOpCount() => _db.getFailedOpCount();
  Future<List<Map<String, dynamic>>> getFailedOps() => _db.getFailedOps();
  Future<void> clearFailedOps() => _db.clearFailedOps();

  // ═══════════════════════════════════════
  // FULL SYNC
  // ═══════════════════════════════════════

  Future<void> syncAll({bool forceRefresh = true}) async {
    try {
      await DashboardSyncService.instance.syncPendingOps();
    } catch (_) {}
    // Drop all cached entity data so we re-save a clean copy from the server
    // (prevents stale offline edits like a renamed role from lingering).
    await _db.clearAllEntities();
    debugPrint('🏛️ Cache: syncAll cleared entity tables before re-save');
    await Future.wait([
      getSections(forceRefresh: forceRefresh).catchError((_) => <String>[]),
      getSubjects(forceRefresh: forceRefresh).catchError((_) => <String>[]),
      getRoles(forceRefresh: forceRefresh).catchError((_) => <String>[]),
      getMyStudents(forceRefresh: forceRefresh).catchError((_) => <String, dynamic>{}),
      getTeacherList(forceRefresh: forceRefresh).catchError((_) => <String, dynamic>{}),
      getStaffList(forceRefresh: forceRefresh).catchError((_) => <String, dynamic>{}),
    ]);
  }

  // ═══════════════════════════════════════
  // WIPE
  // ═══════════════════════════════════════

  Future<void> clearCache() => _db.clearAll();
}
